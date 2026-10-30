// Rule UI + cấu hình điểm (S7b, Spec §7.6c-d + §8.2): xem rule kèm số lần kích hoạt 7 ngày, mô phỏng rule ứng viên trên
// sự kiện thật, sửa = phiên bản mới (đổi logic -> về shadow), chuyển chế độ (active chỉ khi `coTheBatThucThi`), sửa
// threat_config (phiên bản mới) + bật / tắt Under Attack. Mọi ghi: quyền security_admin + step-up + lý do + audit.
import type { Hono } from 'hono';
import { z } from 'zod';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { napCauHinh, xoaDem } from '../threat/nap';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { coTheBatThucThi, phanTichLuat, SHADOW_TOI_THIEU_MS, type DongLuat } from '../thuan/luat';
import {
  cauNapMoPhong,
  doiLogic,
  dongTuThan,
  MO_PHONG_CUA_SO_MS,
  MO_PHONG_TOI_DA_SU_KIEN,
  moPhongLuat,
  SchemaCheDoLuat,
  SchemaMoPhong,
  SchemaSuaLuat,
  type SuKienMoPhong,
} from '../thuan/mo-phong';
import { CAU_HINH_MAC_DINH, schemaCauHinh } from '../thuan/nguy-co';
import { canQuyen, canStepUp } from './xac-thuc';

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

function canJson(c: Ngu): void {
  if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
}

const email = (c: Ngu) => (c.get('quanTri') as { email: string }).email;

const COT_LUAT = 'id, name, condition, "window", threshold, action, enabled, version, mode, shadow_since, updated_by';
type DongLuatDu = DongLuat & { updated_by: string | null };

function moTaLuat(d: DongLuatDu, bayGio: number) {
  const l = phanTichLuat(d);
  return {
    id: d.id,
    ten: d.name,
    phienBan: d.version,
    hong: l === null,
    dieuKien: l?.dieuKien ?? null,
    cuaSo: d.window,
    nguong: d.threshold,
    hanhDong: l?.hanhDong ?? [],
    bat: d.enabled === 1,
    cheDo: d.mode === 'active' ? 'active' : 'shadow',
    shadowTu: d.shadow_since,
    coTheBat: l ? coTheBatThucThi(l, bayGio) : false,
    batDuocLuc: d.mode !== 'active' && d.shadow_since !== null ? d.shadow_since + SHADOW_TOI_THIEU_MS : null,
    suaBoi: d.updated_by,
  };
}

const SchemaCauHinhSua = z.strictObject({ phienBan: z.number().int().min(0), cauHinh: z.unknown(), ghiChu: z.string().trim().min(10).max(500) });
const SchemaUnderAttack = z.strictObject({ bat: z.boolean(), ghiChu: z.string().trim().min(10).max(500) });

export function dangKyLuat(r: Hono<MoiTruongHono>): void {
  r.get('/luat', canQuyen('luat:xem'), async (c) => {
    const d = db(c);
    const bayGio = Date.now();
    const [ds, dem] = await d.batch([
      d.prepare(`SELECT ${COT_LUAT} FROM rules ORDER BY id`),
      d.prepare('SELECT rule_id, SUM(shadow = 0) AS that, SUM(shadow = 1) AS shadow, MAX(ts) AS cuoi FROM rule_hits WHERE ts >= ? GROUP BY rule_id').bind(bayGio - MO_PHONG_CUA_SO_MS),
    ]);
    const theoRule = new Map(((dem?.results ?? []) as { rule_id: string; that: number; shadow: number; cuoi: number }[]).map((x) => [x.rule_id, x]));
    return c.json({
      ds: ((ds?.results ?? []) as DongLuatDu[]).map((x) => {
        const h = theoRule.get(x.id);
        return { ...moTaLuat(x, bayGio), kichHoat7n: { that: h?.that ?? 0, shadow: h?.shadow ?? 0, cuoi: h?.cuoi ?? null } };
      }),
    });
  });

  r.get('/luat/:id', canQuyen('luat:xem'), async (c) => {
    const id = c.req.param('id');
    if (!/^R-\d{3,6}$/.test(id)) throw new LoiApi(400, 'id-loi');
    const d = db(c);
    const [luat, bans, lan] = await d.batch([
      d.prepare(`SELECT ${COT_LUAT} FROM rules WHERE id = ?`).bind(id),
      d.prepare('SELECT version, name, condition, "window", threshold, action, note, created_by, created_at FROM rule_versions WHERE rule_id = ? ORDER BY version DESC LIMIT 50').bind(id),
      d.prepare('SELECT ts, shadow, rule_version, group_key, actions FROM rule_hits WHERE rule_id = ? ORDER BY ts DESC LIMIT 50').bind(id),
    ]);
    const dong = luat?.results[0] as DongLuatDu | undefined;
    if (!dong) throw new LoiApi(404, 'khong-thay');
    const json = (s: string) => {
      try {
        return JSON.parse(s) as unknown;
      } catch {
        return null;
      }
    };
    return c.json({
      luat: moTaLuat(dong, Date.now()),
      phienBan: ((bans?.results ?? []) as Record<string, unknown>[]).map((b) => ({ ...b, condition: json(String(b.condition)), action: json(String(b.action)) })),
      lanKichHoat: lan?.results ?? [],
    });
  });

  // Mô phỏng chỉ đọc (analyst): rule ứng viên chạy trên 7 ngày sự kiện; kèm số kích hoạt thật của rule hiện tại để so.
  r.post('/luat/mo-phong', canQuyen('luat:xem'), async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaMoPhong);
    const d = db(c);
    const den = Date.now();
    const tu = den - MO_PHONG_CUA_SO_MS;
    const cau = cauNapMoPhong(b.than, tu);
    const batDau = Date.now();
    const [sk, thuc] = await d.batch([
      d.prepare(cau.sql).bind(...cau.thamSo),
      d.prepare('SELECT SUM(shadow = 0) AS that, SUM(shadow = 1) AS shadow FROM rule_hits WHERE rule_id = ? AND ts >= ?').bind(b.id ?? '', tu),
    ]);
    const ds = (sk?.results ?? []) as SuKienMoPhong[];
    const catBot = ds.length > MO_PHONG_TOI_DA_SU_KIEN;
    const kq = moPhongLuat(b.than, catBot ? ds.slice(0, MO_PHONG_TOI_DA_SU_KIEN) : ds, tu, den, catBot);
    return c.json({ ...kq, hienTai: b.id ? (thuc?.results[0] ?? null) : null, ms: Date.now() - batDau });
  });

  r.post('/luat/sua', canQuyen('luat:sua'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaSuaLuat);
    const d = db(c);
    const cu = await d.prepare(`SELECT ${COT_LUAT} FROM rules WHERE id = ?`).bind(b.id).first<DongLuatDu>();
    if (!cu) throw new LoiApi(404, 'khong-thay');
    if (cu.version !== b.phienBan) throw new LoiApi(409, 'phien-ban-cu', { hienTai: cu.version });
    const l = phanTichLuat(cu);
    const bayGio = Date.now();
    const logic = !l || doiLogic(l, b.than);
    const moi = dongTuThan(b.than);
    const pb = cu.version + 1;
    const ai = email(c);
    // Ghi có điều kiện phiên bản: người sau ghi đè bản người trước đã đổi -> 0 dòng -> 409.
    const [capNhat] = await d.batch([
      d
        .prepare(
          `UPDATE rules SET name = ?, condition = ?, "window" = ?, threshold = ?, action = ?, version = ?, updated_by = ?, mode = CASE WHEN ? THEN 'shadow' ELSE mode END, shadow_since = CASE WHEN ? THEN ? ELSE shadow_since END WHERE id = ? AND version = ?`,
        )
        .bind(moi.name, moi.condition, moi.window, moi.threshold, moi.action, pb, ai, logic ? 1 : 0, logic ? 1 : 0, bayGio, b.id, cu.version),
      d
        .prepare('INSERT OR IGNORE INTO rule_versions (rule_id, version, name, condition, "window", threshold, action, note, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
        .bind(b.id, pb, moi.name, moi.condition, moi.window, moi.threshold, moi.action, b.ghiChu, ai, bayGio),
    ]);
    if ((capNhat?.meta.changes ?? 0) === 0) throw new LoiApi(409, 'phien-ban-cu');
    xoaDem();
    await ghiAudit(d, {
      id: taoUlid(bayGio),
      actor: ai,
      action: 'luat:sua',
      target: `rule:${b.id}`,
      before: { phienBan: cu.version, ten: cu.name, dieuKien: cu.condition, cuaSo: cu.window, nguong: cu.threshold, hanhDong: cu.action, cheDo: cu.mode },
      after: { phienBan: pb, ...moi, veShadow: logic, ghiChu: b.ghiChu },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true, phienBan: pb, veShadow: logic });
  });

  r.post('/luat/che-do', canQuyen('luat:sua'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaCheDoLuat);
    const d = db(c);
    const cu = await d.prepare(`SELECT ${COT_LUAT} FROM rules WHERE id = ?`).bind(b.id).first<DongLuatDu>();
    if (!cu) throw new LoiApi(404, 'khong-thay');
    if (cu.version !== b.phienBan) throw new LoiApi(409, 'phien-ban-cu', { hienTai: cu.version });
    const l = phanTichLuat(cu);
    const bayGio = Date.now();
    if (b.cheDo === 'active' && (!l || !coTheBatThucThi(l, bayGio))) {
      throw new LoiApi(409, 'chua-du-shadow', { batDuocLuc: cu.shadow_since !== null ? cu.shadow_since + SHADOW_TOI_THIEU_MS : null });
    }
    const [bat, cheDo, shadowTu] =
      b.cheDo === 'tat'
        ? [0, cu.mode, cu.shadow_since]
        : b.cheDo === 'active'
          ? [1, 'active', cu.shadow_since]
          : // Về shadow: giữ mốc cũ nếu đang shadow, đang active thì đếm lại 7 ngày từ bây giờ.
            [1, 'shadow', cu.mode === 'active' || cu.shadow_since === null ? bayGio : cu.shadow_since];
    const kq = await d
      .prepare('UPDATE rules SET enabled = ?, mode = ?, shadow_since = ?, updated_by = ? WHERE id = ? AND version = ?')
      .bind(bat, cheDo, shadowTu, email(c), b.id, cu.version)
      .run();
    if ((kq.meta.changes ?? 0) === 0) throw new LoiApi(409, 'phien-ban-cu');
    xoaDem();
    await ghiAudit(d, {
      id: taoUlid(bayGio),
      actor: email(c),
      action: 'luat:che-do',
      target: `rule:${b.id}`,
      before: { bat: cu.enabled === 1, cheDo: cu.mode, shadowTu: cu.shadow_since },
      after: { bat: bat === 1, cheDo, shadowTu, ghiChu: b.ghiChu },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true });
  });

  // ------------------------------------------------------------ threat_config + Under Attack
  r.get('/cau-hinh-nguy-co', canQuyen('luat:xem'), async (c) => {
    const d = db(c);
    const { results } = await d.prepare('SELECT version, created_by, created_at FROM threat_config ORDER BY version DESC LIMIT 30').all<{ version: number }>();
    const cfg = await napCauHinh(d);
    return c.json({ phienBan: results[0]?.version ?? 0, cauHinh: cfg, macDinh: CAU_HINH_MAC_DINH, lichSu: results });
  });

  const ghiCauHinh = async (c: Ngu, phienBanCu: number, moi: unknown, hanhDong: string, ghiChu: string) => {
    const d = db(c);
    const hienTai = await d.prepare('SELECT version, config FROM threat_config ORDER BY version DESC LIMIT 1').first<{ version: number; config: string }>();
    if ((hienTai?.version ?? 0) !== phienBanCu) throw new LoiApi(409, 'phien-ban-cu', { hienTai: hienTai?.version ?? 0 });
    const bayGio = Date.now();
    const pb = phienBanCu + 1;
    try {
      // version là PRIMARY KEY: hai người lưu cùng lúc -> người sau lỗi UNIQUE -> 409.
      await d.prepare('INSERT INTO threat_config (version, config, created_by, created_at) VALUES (?, ?, ?, ?)').bind(pb, JSON.stringify(moi), email(c), bayGio).run();
    } catch (e) {
      if (/UNIQUE|PRIMARY/i.test(String(e))) throw new LoiApi(409, 'phien-ban-cu');
      throw e;
    }
    xoaDem();
    await ghiAudit(d, {
      id: taoUlid(bayGio),
      actor: email(c),
      action: hanhDong,
      target: `threat_config:${pb}`,
      before: hienTai ? (JSON.parse(hienTai.config) as unknown) : null,
      after: { cauHinh: moi, ghiChu },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return pb;
  };

  r.post('/cau-hinh-nguy-co', canQuyen('cau-hinh-nguy-co'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaCauHinhSua);
    const kq = schemaCauHinh.safeParse(b.cauHinh);
    if (!kq.success) throw new LoiApi(400, 'cau-hinh-loi', kq.error.issues.slice(0, 20).map((i) => i.path.join('.') || i.message));
    const pb = await ghiCauHinh(c, b.phienBan, kq.data, 'cau-hinh-nguy-co:sua', b.ghiChu);
    return c.json({ ok: true, phienBan: pb });
  });

  r.post('/under-attack', canQuyen('cau-hinh-nguy-co'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaUnderAttack);
    const d = db(c);
    const hienTai = await d.prepare('SELECT version FROM threat_config ORDER BY version DESC LIMIT 1').first<{ version: number }>();
    // Đọc thẳng (không qua đệm isolate) để không ghi đè bản vừa lưu ở isolate khác.
    xoaDem();
    const cfg = await napCauHinh(d);
    if (cfg.underAttack === b.bat) return c.json({ ok: true, phienBan: hienTai?.version ?? 0, khongDoi: true });
    const pb = await ghiCauHinh(c, hienTai?.version ?? 0, { ...cfg, underAttack: b.bat }, b.bat ? 'under-attack:bat' : 'under-attack:tat', b.ghiChu);
    return c.json({ ok: true, phienBan: pb });
  });
}
