// Trung tâm cảnh báo SOC (S7a, Spec §8.2 mục 3): danh sách lọc + phân trang, chi tiết (rule, lần kích hoạt, dòng thời gian),
// thao tác đơn / hàng loạt (nhận, ack, đóng có kết luận, mở lại, phân công, ghi chú). Mọi thay đổi vào audit chuỗi băm.
import type { Hono } from 'hono';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { coTelegram, guiTinTelegram } from '../threat/telegram';
import { apThaoTac, cheKhoaNhom, dichKhoaNhom, docLocCanhBao, SchemaThaoTac, truyVanCanhBao, type DongCb } from '../thuan/canh-bao';
import { maHoaCursor } from '../thuan/cursor';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { cheIp, coQuyen, laVaiTro, type VaiTro } from '../thuan/soc';
import { canQuyen, canStepUp } from './xac-thuc';

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

function nguoi(c: Ngu): { email: string; vaiTro: VaiTro } {
  return c.get('quanTri') as { email: string; vaiTro: VaiTro };
}

function canJson(c: Ngu): void {
  if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
}

type DongDs = DongCb & { group_key: string } & Record<string, unknown>;

export function dangKyCanhBao(r: Hono<MoiTruongHono>): void {
  r.get('/canh-bao', canQuyen('canh-bao:xem'), async (c) => {
    const loc = docLocCanhBao(c.req.query());
    const toi = nguoi(c);
    const tv = truyVanCanhBao(loc, toi.email);
    const batDau = Date.now();
    const d = db(c);
    const [ds, dem] = await d.batch([
      d.prepare(tv.sql).bind(...tv.thamSo),
      d.prepare(
        "SELECT SUM(status = 'open') AS mo, SUM(status = 'ack') AS ack, SUM(status IN ('open', 'ack') AND assignee IS NULL) AS chuaGiao, SUM(status IN ('open', 'ack') AND assignee = ?) AS cuaToi, SUM(status IN ('open', 'ack') AND severity IN ('high', 'critical') AND shadow = 0) AS cao FROM alerts",
      ).bind(toi.email),
    ]);
    const dong = (ds?.results ?? []) as DongDs[];
    const conNua = dong.length > tv.gioiHan;
    const trang = dong.slice(0, tv.gioiHan);
    const cuoi = trang.at(-1) as (DongDs & { last_ts: number }) | undefined;
    return c.json({
      ds: trang.map((a) => ({ ...a, group_key: cheKhoaNhom(a.group_key, toi.vaiTro) })),
      tiepTheo: conNua && cuoi ? maHoaCursor({ t: cuoi.last_ts, id: cuoi.id }) : null,
      dem: dem?.results[0] ?? {},
      ms: Date.now() - batDau,
    });
  });

  // Người có thể nhận phân công: quản trị viên còn hiệu lực, vai trò từ analyst.
  r.get('/canh-bao/nguoi-xu-ly', canQuyen('canh-bao:xu-ly'), async (c) => {
    const { results } = await db(c).prepare('SELECT email, role FROM admin_users WHERE disabled_at IS NULL ORDER BY email').all<{ email: string; role: string }>();
    return c.json({ ds: results.filter((u) => laVaiTro(u.role) && coQuyen(u.role, 'canh-bao:xu-ly')).map((u) => u.email) });
  });

  r.get('/canh-bao/:id', canQuyen('canh-bao:xem'), async (c) => {
    const id = c.req.param('id');
    if (!/^[0-9A-Za-z-]{8,40}$/.test(id)) throw new LoiApi(400, 'id-loi');
    const d = db(c);
    const a = await d
      .prepare(
        'SELECT id, rule_id, severity, group_key, count, shadow, first_ts, last_ts, status, assignee, resolution, updated_at, updated_by, notified_at FROM alerts WHERE id = ?',
      )
      .bind(id)
      .first<DongDs & { rule_id: string; first_ts: number }>();
    if (!a) throw new LoiApi(404, 'khong-thay');
    const toi = nguoi(c);
    const dich = dichKhoaNhom(a.group_key);
    const [luat, lan, ghi, tb] = await d.batch([
      d.prepare('SELECT id, name, condition, "window", threshold, action, enabled, version FROM rules WHERE id = ?').bind(a.rule_id),
      d.prepare('SELECT ts, shadow, rule_version, actions FROM rule_hits WHERE rule_id = ? AND group_key = ? ORDER BY ts DESC LIMIT 50').bind(a.rule_id, a.group_key),
      d.prepare('SELECT id, actor, kind, body, ts FROM alert_notes WHERE alert_id = ? ORDER BY ts DESC LIMIT 200').bind(id),
      dich.loai === 'device'
        ? d.prepare('SELECT id, status, risk_score, model, app_version, last_seen FROM devices WHERE id = ?').bind(dich.giaTri)
        : d.prepare('SELECT NULL AS id WHERE 0'),
    ]);
    const quyTac = luat?.results[0] as (Record<string, unknown> & { condition: string }) | undefined;
    return c.json({
      canhBao: { ...a, group_key: cheKhoaNhom(a.group_key, toi.vaiTro) },
      dich: { loai: dich.loai, giaTri: dich.loai === 'ip' ? cheIp(dich.giaTri, toi.vaiTro) : dich.giaTri },
      rule: quyTac ? { ...quyTac, condition: JSON.parse(quyTac.condition) as unknown } : null,
      lanKichHoat: lan?.results ?? [],
      dongThoiGian: ghi?.results ?? [],
      thietBi: tb?.results[0] ?? null,
      telegram: coTelegram(c.env),
    });
  });

  r.post('/canh-bao/thao-tac', canQuyen('canh-bao:xu-ly'), async (c) => {
    canJson(c);
    const tt = phanTichBody(await c.req.text(), SchemaThaoTac);
    const toi = nguoi(c);
    const d = db(c);
    if (tt.hanhDong === 'phan-cong' && tt.nguoi) {
      const u = await d.prepare('SELECT role FROM admin_users WHERE email = ? AND disabled_at IS NULL').bind(tt.nguoi).first<{ role: string }>();
      if (!u || !laVaiTro(u.role) || !coQuyen(u.role, 'canh-bao:xu-ly')) throw new LoiApi(400, 'nguoi-xu-ly-loi');
    }
    const { results } = await d
      .prepare(`SELECT id, status, assignee, resolution FROM alerts WHERE id IN (${tt.ids.map(() => '?').join(', ')})`)
      .bind(...tt.ids)
      .all<DongCb>();
    const bayGio = Date.now();
    const doi = results.flatMap((dong) => {
      const m = apThaoTac(dong, tt, toi.email);
      return m ? [{ truoc: dong, moi: m }] : [];
    });
    if (doi.length > 0) {
      const lenh = doi.flatMap(({ truoc, moi }, i) => [
        // Kiểm trạng thái cũ trong WHERE: hai người thao tác cùng lúc -> người sau không ghi đè âm thầm.
        d
          .prepare('UPDATE alerts SET status = ?, assignee = ?, resolution = ?, updated_at = ?, updated_by = ? WHERE id = ? AND status = ?')
          .bind(moi.status, moi.assignee, moi.resolution, bayGio, toi.email, moi.id, truoc.status),
        ...moi.ghi.map((g, j) =>
          d
            .prepare('INSERT INTO alert_notes (id, alert_id, actor, kind, body, ts) VALUES (?, ?, ?, ?, ?, ?)')
            .bind(taoUlid(bayGio + i * 16 + j), moi.id, toi.email, g.kind, g.body, bayGio),
        ),
      ]);
      try {
        await d.batch(lenh);
      } catch (e) {
        // Mở lại khi (rule, nhóm) đã có cảnh báo hoạt động khác -> vi phạm chỉ mục gộp.
        if (/UNIQUE/i.test(String(e))) throw new LoiApi(409, 'da-co-canh-bao-hoat-dong');
        throw e;
      }
      await ghiAudit(d, {
        id: taoUlid(bayGio),
        actor: toi.email,
        action: `canh-bao:${tt.hanhDong}`,
        target: doi.length === 1 ? `alert:${doi[0]?.moi.id}` : `alerts:${doi.length}`,
        before: doi.map(({ truoc }) => ({ id: truoc.id, status: truoc.status, assignee: truoc.assignee })),
        after: { status: doi[0]?.moi.status, assignee: doi[0]?.moi.assignee ?? null, ketLuan: tt.ketLuan ?? null, ghiChu: tt.ghiChu ? tt.ghiChu.length : 0 },
        ip: c.get('ip') || null,
        ts: bayGio,
      });
    }
    return c.json({ capNhat: doi.length, boQua: tt.ids.length - doi.length });
  });

  // Thử kênh Telegram (Super Admin, step-up): kiểm cấu hình bí mật mà không chờ cảnh báo thật.
  r.post('/canh-bao/thu-telegram', canQuyen('quan-tri-vien'), canStepUp, async (c) => {
    canJson(c);
    if (!coTelegram(c.env)) throw new LoiApi(409, 'chua-cau-hinh-telegram');
    const ok = await guiTinTelegram(c.env, `✅ [${c.env.MOI_TRUONG}] La bàn SOC: kênh Telegram hoạt động.`);
    if (!ok) throw new LoiApi(502, 'telegram-loi');
    return c.json({ ok: true });
  });
}
