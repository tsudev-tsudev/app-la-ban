// Can thiệp SOC (S7b, Spec §8.2-5): danh sách enforcement + lọc, chặn / gỡ chặn (lý do bắt buộc + step-up), thu hồi phiên
// thiết bị, duyệt đề xuất chặn dải `pending_approval`, four-eyes cho thao tác hàng loạt (yêu cầu -> người thứ hai duyệt).
import type { Hono } from 'hono';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { ghiLog } from '../mw/ghi-log';
import { apDungChan, goChan } from '../threat/can-thiep';
import { dongBoLists } from '../threat/dong-bo-lists';
import { napCauHinh, xoaDem } from '../threat/nap';
import {
  canDuyetGoChan,
  dieuKienTrangThai,
  docLocThucThi,
  kiemQuyet,
  kiemYeuCauChan,
  loaiDuyet,
  SchemaChan,
  SchemaGoChan,
  SchemaHuyYeuCau,
  SchemaQuyet,
  SchemaThuHoiPhien,
  YEU_CAU_HAN_MS,
  type YeuCauChan,
  type YeuCauGoChan,
} from '../thuan/can-thiep';
import { docGioiHanTrang, giaiMaCursor, maHoaCursor } from '../thuan/cursor';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { canQuyen, canStepUp } from './xac-thuc';

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

function canJson(c: Ngu): void {
  if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
}

const email = (c: Ngu) => (c.get('quanTri') as { email: string }).email;

/** Đồng bộ Cloudflare Lists sau khi trả lời (SEC-DET <= 30 s); lỗi chỉ ghi log - cron 5 phút sẽ đồng bộ lại. */
function dongBoNen(c: Ngu, can: boolean): void {
  if (!can) return;
  c.executionCtx.waitUntil(dongBoLists(c.env).then(() => undefined, (e: unknown) => ghiLog('error', 'dong-bo-lists', { loi: String(e) })));
}

type DongYeuCau = { id: string; kind: 'chan' | 'go-chan'; payload: string; reason: string; created_by: string; created_at: number; expires_at: number; status: string };

export function dangKyCanThiep(r: Hono<MoiTruongHono>): void {
  r.get('/thuc-thi', canQuyen('luat:xem'), async (c) => {
    const loc = docLocThucThi(c.req.query());
    const bayGio = Date.now();
    const dk: string[] = [];
    const ts: (string | number)[] = [];
    const tt = dieuKienTrangThai(loc.trangThai);
    if (tt) {
      dk.push(tt.sql);
      ts.push(...Array<number>(tt.soThamSo).fill(bayGio));
    }
    if (loc.loai) {
      dk.push('target_type = ?');
      ts.push(loc.loai);
    }
    if (loc.nguon) {
      dk.push('source = ?');
      ts.push(loc.nguon);
    }
    // Schema chỉ cho [0-9A-Za-z.:/-] nên không có ký tự đại diện LIKE lọt vào.
    if (loc.q) {
      dk.push('target_value LIKE ?');
      ts.push(`${loc.q}%`);
    }
    const cursor = giaiMaCursor(loc.cursor);
    if (cursor) {
      dk.push('(created_at, id) < (?, ?)');
      ts.push(cursor.t, cursor.id);
    }
    const gioiHan = docGioiHanTrang(loc.limit);
    const d = db(c);
    const [ds, dem] = await d.batch([
      // nosemgrep: la-ban-sql-noi-chuoi - dk chỉ gồm mệnh đề literal, giá trị qua bind
      d
        .prepare(
          `SELECT id, target_type, target_value, action, reason, created_by, approved_by, created_at, expires_at, revoked_at, source, pending_approval, rule_id, level FROM enforcements${dk.length ? ` WHERE ${dk.join(' AND ')}` : ''} ORDER BY created_at DESC, id DESC LIMIT ?`,
        )
        .bind(...ts, gioiHan + 1),
      d
        .prepare(
          'SELECT SUM(revoked_at IS NULL AND expires_at > ?1 AND (pending_approval = 0 OR approved_by IS NOT NULL)) AS hieuLuc, SUM(revoked_at IS NULL AND expires_at > ?1 AND pending_approval = 1 AND approved_by IS NULL) AS choDuyet, (SELECT COUNT(*) FROM approval_requests WHERE status = \'pending\' AND expires_at > ?1) AS yeuCau FROM enforcements',
        )
        .bind(bayGio),
    ]);
    const dong = (ds?.results ?? []) as { id: string; created_at: number }[];
    const trang = dong.slice(0, gioiHan);
    const cuoi = trang.at(-1);
    const cfg = await napCauHinh(d, bayGio);
    return c.json({
      ds: trang,
      tiepTheo: dong.length > gioiHan && cuoi ? maHoaCursor({ t: cuoi.created_at, id: cuoi.id }) : null,
      dem: dem?.results[0] ?? {},
      underAttack: cfg.underAttack,
    });
  });

  r.post('/thuc-thi/chan', canQuyen('can-thiep'), canStepUp, async (c) => {
    canJson(c);
    const yc = kiemYeuCauChan(phanTichBody(await c.req.text(), SchemaChan));
    const d = db(c);
    const bayGio = Date.now();
    const cfg = await napCauHinh(d, bayGio);
    const loai = loaiDuyet(yc, cfg.underAttack);
    if (loai === 'yeu-cau') {
      const id = await taoYeuCau(c, 'chan', yc, yc.lyDo, bayGio);
      return c.json({ loai, yeuCau: id }, 202);
    }
    const kq = await apDungChan(d, cfg, yc, { tacNhan: email(c), duyetBoi: null, choDuyet: loai === 'de-xuat', ip: c.get('ip') || null, bayGio });
    dongBoNen(c, kq.canDongBo);
    return c.json({ loai, ...kq }, kq.tao.length ? 201 : 200);
  });

  r.post('/thuc-thi/go', canQuyen('can-thiep'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaGoChan);
    const yc: YeuCauGoChan = { ids: [...new Set(b.ids)], lyDo: b.lyDo };
    const bayGio = Date.now();
    if (canDuyetGoChan(yc.ids.length)) {
      const id = await taoYeuCau(c, 'go-chan', yc, yc.lyDo, bayGio);
      return c.json({ loai: 'yeu-cau', yeuCau: id }, 202);
    }
    const d = db(c);
    const kq = await goChan(d, await napCauHinh(d, bayGio), yc.ids, { tacNhan: email(c), duyetBoi: null, lyDo: yc.lyDo, ip: c.get('ip') || null, bayGio });
    if (kq.go === 0) throw new LoiApi(404, 'khong-thay');
    dongBoNen(c, kq.canDongBo);
    return c.json({ loai: 'ngay', ...kq });
  });

  // Duyệt / bác đề xuất chặn dải - ASN (do engine hoặc người khác tạo). Người tạo không tự duyệt (CHECK D1 + kiểm ở đây).
  r.post('/thuc-thi/duyet', canQuyen('can-thiep:duyet'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaQuyet);
    const d = db(c);
    const bayGio = Date.now();
    const e = await d
      .prepare('SELECT id, target_type, target_value, action, created_by, expires_at FROM enforcements WHERE id = ? AND pending_approval = 1 AND approved_by IS NULL AND revoked_at IS NULL')
      .bind(b.id)
      .first<{ id: string; target_type: string; target_value: string; action: string; created_by: string; expires_at: number }>();
    if (!e) throw new LoiApi(404, 'khong-thay');
    kiemQuyet({ created_by: e.created_by, status: 'pending', expires_at: e.expires_at }, email(c), bayGio);
    const kq = b.dongY
      ? await d.prepare('UPDATE enforcements SET approved_by = ? WHERE id = ? AND approved_by IS NULL AND revoked_at IS NULL').bind(email(c), b.id).run()
      : await d.prepare('UPDATE enforcements SET revoked_at = ? WHERE id = ? AND approved_by IS NULL AND revoked_at IS NULL').bind(bayGio, b.id).run();
    if ((kq.meta.changes ?? 0) === 0) throw new LoiApi(409, 'da-quyet');
    xoaDem();
    await ghiAudit(d, {
      id: taoUlid(bayGio),
      actor: email(c),
      action: b.dongY ? 'can-thiep:duyet' : 'can-thiep:bac',
      target: `${e.target_type}:${e.target_value}`,
      before: { id: e.id, taoBoi: e.created_by, choDuyet: true },
      after: { dongY: b.dongY, ghiChu: b.ghiChu ?? null },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    dongBoNen(c, b.dongY && (e.target_type === 'ip' || e.target_type === 'cidr'));
    return c.json({ ok: true });
  });

  r.post('/thiet-bi/thu-hoi-phien', canQuyen('can-thiep'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaThuHoiPhien);
    const d = db(c);
    const bayGio = Date.now();
    const tb = await d.prepare('SELECT id FROM devices WHERE id = ?').bind(b.thietBi).first();
    if (!tb) throw new LoiApi(404, 'khong-thay');
    const kq = await d
      .prepare("UPDATE sessions SET revoked_at = ?, ly_do_thu_hoi = 'soc' WHERE device_id = ? AND revoked_at IS NULL AND expires_at > ?")
      .bind(bayGio, b.thietBi, bayGio)
      .run();
    await ghiAudit(d, {
      id: taoUlid(bayGio),
      actor: email(c),
      action: 'can-thiep:thu-hoi-phien',
      target: `device:${b.thietBi}`,
      before: null,
      after: { soPhien: kq.meta.changes ?? 0, lyDo: b.lyDo },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true, soPhien: kq.meta.changes ?? 0 });
  });

  // ------------------------------------------------------------ four-eyes
  r.get('/yeu-cau-duyet', canQuyen('luat:xem'), async (c) => {
    const tatCa = c.req.query('trangThai') === 'tat-ca';
    const { results } = await db(c)
      .prepare(
        `SELECT id, kind, payload, reason, created_by, created_at, expires_at, status, decided_by, decided_at, decision_note FROM approval_requests${tatCa ? '' : " WHERE status = 'pending'"} ORDER BY created_at DESC LIMIT 100`,
      )
      .all<DongYeuCau & Record<string, unknown>>();
    return c.json({ ds: results.map((x) => ({ ...x, payload: JSON.parse(x.payload) as unknown })), toi: email(c) });
  });

  r.post('/yeu-cau-duyet/quyet', canQuyen('can-thiep:duyet'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaQuyet);
    const d = db(c);
    const bayGio = Date.now();
    const yc = await d.prepare('SELECT id, kind, payload, reason, created_by, created_at, expires_at, status FROM approval_requests WHERE id = ?').bind(b.id).first<DongYeuCau>();
    if (!yc) throw new LoiApi(404, 'khong-thay');
    const toi = email(c);
    kiemQuyet(yc, toi, bayGio);
    // Giành quyền quyết bằng điều kiện status: hai người duyệt cùng lúc -> chỉ một người thắng.
    const kq = await d
      .prepare("UPDATE approval_requests SET status = ?, decided_by = ?, decided_at = ?, decision_note = ? WHERE id = ? AND status = 'pending'")
      .bind(b.dongY ? 'approved' : 'rejected', toi, bayGio, b.ghiChu ?? null, b.id)
      .run();
    if ((kq.meta.changes ?? 0) === 0) throw new LoiApi(409, 'da-quyet');
    let ketQua: unknown = null;
    if (b.dongY) {
      const cfg = await napCauHinh(d, bayGio);
      const ip = c.get('ip') || null;
      if (yc.kind === 'chan') {
        const chan = JSON.parse(yc.payload) as YeuCauChan;
        // Đã qua four-eyes: hiệu lực ngay (kể cả dải / ASN), người tạo yêu cầu là created_by, người duyệt là approved_by.
        const kqChan = await apDungChan(d, cfg, chan, { tacNhan: yc.created_by, duyetBoi: toi, choDuyet: false, ip, bayGio, yeuCauId: yc.id });
        dongBoNen(c, kqChan.canDongBo);
        ketQua = kqChan;
      } else {
        const go = JSON.parse(yc.payload) as YeuCauGoChan;
        const kqGo = await goChan(d, cfg, go.ids, { tacNhan: yc.created_by, duyetBoi: toi, lyDo: go.lyDo, ip, bayGio, yeuCauId: yc.id });
        dongBoNen(c, kqGo.canDongBo);
        ketQua = kqGo;
      }
    }
    await ghiAudit(d, {
      id: taoUlid(bayGio + 1),
      actor: toi,
      action: b.dongY ? 'four-eyes:duyet' : 'four-eyes:bac',
      target: `approval:${yc.id}`,
      before: { loai: yc.kind, taoBoi: yc.created_by },
      after: { ghiChu: b.ghiChu ?? null },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true, ketQua });
  });

  r.post('/yeu-cau-duyet/huy', canQuyen('can-thiep'), async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaHuyYeuCau);
    const d = db(c);
    const bayGio = Date.now();
    const kq = await d
      .prepare("UPDATE approval_requests SET status = 'cancelled', decided_by = created_by, decided_at = ? WHERE id = ? AND status = 'pending' AND created_by = ?")
      .bind(bayGio, b.id, email(c))
      .run();
    if ((kq.meta.changes ?? 0) === 0) throw new LoiApi(404, 'khong-thay');
    await ghiAudit(d, { id: taoUlid(bayGio), actor: email(c), action: 'four-eyes:huy', target: `approval:${b.id}`, before: null, after: null, ip: c.get('ip') || null, ts: bayGio });
    return c.json({ ok: true });
  });
}

async function taoYeuCau(c: Ngu, loai: 'chan' | 'go-chan', payload: YeuCauChan | YeuCauGoChan, lyDo: string, bayGio: number): Promise<string> {
  const d = db(c);
  const id = taoUlid(bayGio);
  await d
    .prepare('INSERT INTO approval_requests (id, kind, payload, reason, created_by, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .bind(id, loai, JSON.stringify(payload), lyDo, email(c), bayGio, bayGio + YEU_CAU_HAN_MS)
    .run();
  const so = 'dich' in payload ? payload.dich.length : payload.ids.length;
  await ghiAudit(d, {
    id: taoUlid(bayGio + 1),
    actor: email(c),
    action: 'four-eyes:tao',
    target: `approval:${id}`,
    before: null,
    after: { loai, so, lyDo },
    ip: c.get('ip') || null,
    ts: bayGio,
  });
  return id;
}

