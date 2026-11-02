// SOC S7c1: duyệt khiếu nại (Spec §8.2-6) + xem / kiểm chuỗi audit (SEC-DATA DAT-02, cổng S7 "audit sửa tay bị phát hiện").
// Chấp nhận khiếu nại = gỡ mọi chặn thiết bị còn hiệu lực + đưa điểm rủi ro về 0 (báo động giả), có lý do + step-up +
// audit. Ghi trạng thái khiếu nại có điều kiện `status = 'open'` nên hai người quyết cùng lúc chỉ một người thắng.
import type { Hono } from 'hono';
import { docChuoiTu, ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { goChan, tinhLaiThietBi } from '../threat/can-thiep';
import { napCauHinh } from '../threat/nap';
import { HASH_GOC, kiemChuoiAudit } from '../thuan/audit';
import { docGioiHanTrang, giaiMaCursor, maHoaCursor } from '../thuan/cursor';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { maRef } from '../thuan/kenh';
import { docLocAudit, docLocKhieuNai, LO_KIEM_AUDIT, SchemaQuyetKhieuNai, truyVanAudit } from '../thuan/khieu-nai';
import { LoiApi } from '../thuan/loi';
import { canQuyen, canStepUp } from './xac-thuc';

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

const email = (c: Ngu) => (c.get('quanTri') as { email: string }).email;

function json(s: string | null): unknown {
  if (!s) return null;
  try {
    return JSON.parse(s);
  } catch {
    return s;
  }
}

type DongKhieuNai = { id: string; device_id: string; ts: number } & Record<string, unknown>;

export function dangKyKhieuNai(r: Hono<MoiTruongHono>): void {
  r.get('/khieu-nai', canQuyen('khieu-nai:xem'), async (c) => {
    const loc = docLocKhieuNai(c.req.query());
    const dk: string[] = [];
    const ts: (string | number)[] = [];
    const tt = loc.trangThai ?? 'open';
    if (tt !== 'tat-ca') {
      dk.push('a.status = ?');
      ts.push(tt);
    }
    const cursor = giaiMaCursor(loc.cursor);
    if (cursor) {
      dk.push('(a.ts, a.id) < (?, ?)');
      ts.push(cursor.t, cursor.id);
    }
    const gioiHan = docGioiHanTrang(loc.limit);
    const d = db(c);
    const [ds, dem] = await d.batch([
      // nosemgrep: la-ban-sql-noi-chuoi - dk chỉ gồm mệnh đề literal, giá trị qua bind
      d
        .prepare(
          `SELECT a.id, a.device_id, a.enforcement_id, a.message, a.status, a.reviewed_by, a.reviewed_at, a.decision_note, a.ts, a.contact, a.lang, d.status AS device_status, d.model, d.app_version, d.risk_score, e.action AS e_action, e.reason AS e_reason, e.source AS e_source, e.created_at AS e_created_at, e.expires_at AS e_expires_at, e.revoked_at AS e_revoked_at FROM appeals a JOIN devices d ON d.id = a.device_id LEFT JOIN enforcements e ON e.id = a.enforcement_id${dk.length ? ` WHERE ${dk.join(' AND ')}` : ''} ORDER BY a.ts DESC, a.id DESC LIMIT ?`,
        )
        .bind(...ts, gioiHan + 1),
      d.prepare('SELECT status AS k, COUNT(*) AS n FROM appeals GROUP BY status'),
    ]);
    const dong = (ds?.results ?? []) as DongKhieuNai[];
    const trang = dong.slice(0, gioiHan);
    const cuoi = trang.at(-1);
    return c.json({
      ds: trang.map((x) => ({ ...x, ref: maRef(x.device_id) })),
      tiepTheo: dong.length > gioiHan && cuoi ? maHoaCursor({ t: cuoi.ts, id: cuoi.id }) : null,
      dem: Object.fromEntries(((dem?.results ?? []) as { k: string; n: number }[]).map((x) => [x.k, x.n])),
    });
  });

  r.post('/khieu-nai/quyet', canQuyen('khieu-nai:xu-ly'), canStepUp, async (c) => {
    if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
    const b = phanTichBody(await c.req.text(), SchemaQuyetKhieuNai);
    const d = db(c);
    const bayGio = Date.now();
    const ai = email(c);
    const kn = await d.prepare('SELECT id, device_id, status FROM appeals WHERE id = ?').bind(b.id).first<{ id: string; device_id: string; status: string }>();
    if (!kn) throw new LoiApi(404, 'khong-thay');
    const chapNhan = b.quyet === 'chap-nhan';
    const ghi = await d
      .prepare("UPDATE appeals SET status = ?, reviewed_by = ?, reviewed_at = ?, decision_note = ? WHERE id = ? AND status = 'open'")
      .bind(chapNhan ? 'approved' : 'rejected', ai, bayGio, b.ghiChu, b.id)
      .run();
    if (!ghi.meta.changes) throw new LoiApi(409, 'da-quyet');

    let go = 0;
    let diemTruoc: number | null = null;
    if (chapNhan) {
      const cfg = await napCauHinh(d, bayGio);
      const [chan, tb] = await d.batch([
        d.prepare("SELECT id FROM enforcements WHERE target_type = 'device' AND target_value = ? AND revoked_at IS NULL AND expires_at > ?").bind(kn.device_id, bayGio),
        d.prepare('SELECT risk_score FROM devices WHERE id = ?').bind(kn.device_id),
      ]);
      diemTruoc = ((tb?.results[0] ?? null) as { risk_score: number } | null)?.risk_score ?? null;
      await d.prepare('UPDATE devices SET risk_score = 0 WHERE id = ?').bind(kn.device_id).run();
      const ids = ((chan?.results ?? []) as { id: string }[]).map((x) => x.id);
      if (ids.length) {
        go = (await goChan(d, cfg, ids, { tacNhan: ai, duyetBoi: null, lyDo: `Khiếu nại ${kn.id}: ${b.ghiChu}`.slice(0, 500), ip: c.get('ip') || null, bayGio })).go;
      } else {
        await tinhLaiThietBi(d, cfg, [kn.device_id], bayGio);
      }
    }
    await ghiAudit(d, {
      id: taoUlid(bayGio),
      actor: ai,
      action: chapNhan ? 'khieu-nai:chap-nhan' : 'khieu-nai:tu-choi',
      target: `device:${kn.device_id}`,
      before: { khieuNai: kn.id, trangThai: 'open', ...(diemTruoc === null ? {} : { diem: diemTruoc }) },
      after: { ghiChu: b.ghiChu, goChan: go },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    const sau = await d.prepare('SELECT status FROM devices WHERE id = ?').bind(kn.device_id).first<{ status: string }>();
    return c.json({ ok: true, goChan: go, trangThaiThietBi: sau?.status ?? null });
  });

  // ---------------------------------------------------------------- audit
  r.get('/audit', canQuyen('audit:xem'), async (c) => {
    const loc = docLocAudit(c.req.query());
    const tv = truyVanAudit(loc);
    const gioiHan = docGioiHanTrang(loc.limit);
    // nosemgrep: la-ban-sql-noi-chuoi - tv.where sinh từ truyVanAudit (thuan, có test), giá trị qua bind
    const { results } = await db(c)
      .prepare(`SELECT rowid AS so, id, actor, action, target, before, after, ip, ts, hash_prev, hash_self FROM audit_logs${tv.where} ORDER BY rowid DESC LIMIT ?`)
      .bind(...tv.thamSo, gioiHan + 1)
      .all<{ so: number; before: string | null; after: string | null } & Record<string, unknown>>();
    const trang = results.slice(0, gioiHan);
    return c.json({
      ds: trang.map((x) => ({ ...x, before: json(x.before), after: json(x.after) })),
      tiepTheo: results.length > gioiHan ? String(trang.at(-1)?.so ?? '') : null,
    });
  });

  // Kiểm toàn chuỗi theo lô (rowid tăng dần): dòng bị sửa tay / chèn / xoá giữa chuỗi -> trả vị trí đầu tiên sai. Chính
  // việc kiểm cũng được ghi audit (ai kiểm, kết quả) - nối vào chuỗi SAU khi kiểm xong.
  r.post('/audit/kiem', canQuyen('audit:xem'), async (c) => {
    const d = db(c);
    const batDau = Date.now();
    let truoc = HASH_GOC;
    let sau = 0;
    let tong = 0;
    let loi: { so: number; id: string; ts: number } | null = null;
    for (;;) {
      const lo = await docChuoiTu(d, sau, LO_KIEM_AUDIT);
      if (lo.length === 0) break;
      const vt = await kiemChuoiAudit(lo, truoc);
      if (vt >= 0) {
        const x = lo[vt];
        if (x) loi = { so: x.so, id: x.id, ts: x.ts };
        tong += vt;
        break;
      }
      tong += lo.length;
      const cuoi = lo.at(-1);
      if (!cuoi || lo.length < LO_KIEM_AUDIT) break;
      truoc = cuoi.hash_self;
      sau = cuoi.so;
    }
    const kq = { nguyenVen: loi === null, soDongDung: tong, dongLoi: loi, ms: Date.now() - batDau };
    const bayGio = Date.now();
    await ghiAudit(d, { id: taoUlid(bayGio), actor: email(c), action: 'audit:kiem', target: 'audit_logs', before: null, after: kq, ip: c.get('ip') || null, ts: bayGio });
    return c.json(kq);
  });
}
