// SOC trang Quyền lợi (M1a bước 4 - 5, SEC-IAP, Q55): tra cứu theo thiết bị / băm token / mã đơn, chi tiết (thiết bị gắn,
// lịch sử xác minh - RTDN - thu hồi), số liệu (D1) + doanh thu ước tính (Analytics Engine, không PII), gỡ thiết bị khỏi
// quyền lợi (chống chia sẻ token IAP-04: người đổi máy hợp lệ bị chặn ở N thiết bị), thu hồi thủ công four-eyes + audit.
import type { Hono } from 'hono';
import { ghiAudit } from '../d1/audit';
import type { MoiTruongHono, Ngu } from '../moi-truong';
import { kiemQuyet } from '../thuan/can-thiep';
import { maHoaCursor } from '../thuan/cursor';
import { phanTichBody } from '../thuan/dau-vao';
import { taoUlid } from '../thuan/dinh-danh';
import { LoiApi } from '../thuan/loi';
import { CUA_SO_HOAT_DONG_MS, THIET_BI_TOI_DA_MAC_DINH } from '../thuan/quyen-loi';
import {
  COT_QL,
  docLocQl,
  kiemThuHoiDuoc,
  NGAY_DOANH_THU,
  QL_YEU_CAU_HAN_MS,
  rutGonBam,
  SchemaGoThietBiQl,
  SchemaHuyQl,
  SchemaQuyetQl,
  SchemaThuHoiQl,
  sqlDoanhThu,
  sqlDsQl,
  tongHopDoanhThu,
  type DongDoanhThu,
  type TongDoanhThu,
} from '../thuan/quyen-loi-soc';
import { canQuyen, canStepUp } from './xac-thuc';

const HET_GIO_AE_MS = 5_000;

function db(c: Ngu): D1Database {
  if (!c.env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return c.env.DB;
}

function canJson(c: Ngu): void {
  if (!/^application\/json\b/i.test(c.req.header('content-type') ?? '')) throw new LoiApi(415, 'can-json');
}

const email = (c: Ngu) => (c.get('quanTri') as { email: string }).email;

type DongQl = { id: string; account_hash: string | null; updated_at: number; state: string; product_id: string; source: string } & Record<string, unknown>;

const anBam = <T extends { account_hash: string | null }>(x: T): T => ({ ...x, account_hash: rutGonBam(x.account_hash) });

function thietBiToiDa(c: Ngu): number {
  const n = Number(c.env.QL_THIET_BI_TOI_DA);
  return Number.isInteger(n) && n >= 1 && n <= 50 ? n : THIET_BI_TOI_DA_MAC_DINH;
}

/** Doanh thu ước tính từ AE. Thiếu token / bảng -> null + lý do (SOC hiện "chưa cấu hình", không lỗi cả trang). */
async function doanhThuAe(c: Ngu, ngay: number): Promise<{ duLieu: TongDoanhThu | null; lyDo: string | null }> {
  const env = c.env;
  if (!env.CF_AE_TOKEN || !env.CF_ACCOUNT_ID || !env.AE_BANG) return { duLieu: null, lyDo: 'thieu-cau-hinh' };
  try {
    const res = await fetch(`https://api.cloudflare.com/client/v4/accounts/${env.CF_ACCOUNT_ID}/analytics_engine/sql`, {
      method: 'POST',
      headers: { authorization: `Bearer ${env.CF_AE_TOKEN}` },
      body: sqlDoanhThu(env.AE_BANG, ngay),
      signal: AbortSignal.timeout(HET_GIO_AE_MS),
    });
    if (!res.ok) return { duLieu: null, lyDo: `ae-${res.status}` };
    const { data } = (await res.json()) as { data?: DongDoanhThu[] };
    return { duLieu: tongHopDoanhThu(data ?? []), lyDo: null };
  } catch {
    return { duLieu: null, lyDo: 'ae-loi' };
  }
}

type DongYeuCau = { id: string; entitlement_id: string; kind: string; reason: string; created_by: string; created_at: number; expires_at: number; status: string };

export function dangKyQuyenLoi(r: Hono<MoiTruongHono>): void {
  r.get('/quyen-loi', canQuyen('quyen-loi:xem'), async (c) => {
    const loc = docLocQl(c.req.query());
    const { sql, thamSo } = sqlDsQl(loc, Date.now());
    // nosemgrep: la-ban-sql-noi-chuoi - sqlDsQl chỉ ghép mệnh đề literal, giá trị qua bind
    const { results } = await db(c).prepare(sql).bind(...thamSo).all<DongQl>();
    const trang = results.slice(0, loc.gioiHan);
    const cuoi = trang.at(-1);
    return c.json({
      ds: trang.map(anBam),
      tiepTheo: results.length > loc.gioiHan && cuoi ? maHoaCursor({ t: cuoi.updated_at, id: cuoi.id }) : null,
    });
  });

  r.get('/quyen-loi/chi-tiet', canQuyen('quyen-loi:xem'), async (c) => {
    const id = c.req.query('id') ?? '';
    if (!/^[0-9A-Za-z:_-]{8,60}$/.test(id)) throw new LoiApi(400, 'id-loi');
    const d = db(c);
    const bayGio = Date.now();
    const [ql, tb, sk, yc] = await d.batch([
      // nosemgrep: la-ban-sql-noi-chuoi - COT_QL là hằng
      d.prepare(`SELECT ${COT_QL} FROM quyen_loi q WHERE q.id = ?`).bind(id),
      d
        .prepare(
          `SELECT l.device_id, l.linked_at, l.seen_at, d.model, d.app_version, d.status, d.risk_score, (l.seen_at > ?) AS hoat_dong
           FROM quyen_loi_devices l LEFT JOIN devices d ON d.id = l.device_id WHERE l.entitlement_id = ? ORDER BY l.seen_at DESC LIMIT 100`,
        )
        .bind(bayGio - CUA_SO_HOAT_DONG_MS, id),
      d.prepare('SELECT id, kind, detail, ts FROM quyen_loi_events WHERE entitlement_id = ? ORDER BY ts DESC, id DESC LIMIT 200').bind(id),
      d
        .prepare('SELECT id, kind, reason, created_by, created_at, expires_at, status, decided_by, decided_at, decision_note FROM quyen_loi_requests WHERE entitlement_id = ? ORDER BY created_at DESC LIMIT 50')
        .bind(id),
    ]);
    const dong = ql?.results[0] as DongQl | undefined;
    if (!dong) throw new LoiApi(404, 'khong-thay');
    return c.json({
      quyenLoi: anBam(dong),
      thietBi: tb?.results ?? [],
      suKien: ((sk?.results ?? []) as { detail: string | null }[]).map((x) => ({ ...x, detail: x.detail ? (JSON.parse(x.detail) as unknown) : null })),
      yeuCau: yc?.results ?? [],
      toiDa: thietBiToiDa(c),
      toi: email(c),
    });
  });

  r.get('/quyen-loi/so-lieu', canQuyen('quyen-loi:so-lieu'), async (c) => {
    const ngay = Number(c.req.query('ngay') ?? '30');
    if (!(NGAY_DOANH_THU as readonly number[]).includes(ngay)) throw new LoiApi(400, 'ngay-loi');
    const d = db(c);
    const bayGio = Date.now();
    const tu = bayGio - ngay * 86_400_000;
    const [nhom, suKien, cho] = await d.batch([
      d
        .prepare(
          `SELECT source, product_id, count(*) AS tong,
             sum(state IN ('active', 'grace', 'canceled') AND (expires_at IS NULL OR expires_at > ?1)) AS hieu_luc,
             sum(state = 'revoked') AS thu_hoi, sum(test_purchase) AS mua_thu
           FROM quyen_loi GROUP BY source, product_id ORDER BY source, product_id`,
        )
        .bind(bayGio),
      d.prepare('SELECT kind, count(*) AS n FROM quyen_loi_events WHERE ts >= ? GROUP BY kind ORDER BY n DESC').bind(tu),
      d.prepare("SELECT count(*) AS n FROM quyen_loi_requests WHERE status = 'pending' AND expires_at > ?").bind(bayGio),
    ]);
    const dt = await doanhThuAe(c, ngay);
    return c.json({
      ngay,
      theoSanPham: nhom?.results ?? [],
      suKien: suKien?.results ?? [],
      choDuyet: (cho?.results[0] as { n: number } | undefined)?.n ?? 0,
      toiDa: thietBiToiDa(c),
      doanhThu: dt.duLieu,
      doanhThuLyDo: dt.lyDo,
    });
  });

  // Gỡ một thiết bị khỏi quyền lợi (người dùng đổi máy, token chạm N thiết bị). Không mất quyền lợi của thiết bị khác.
  r.post('/quyen-loi/go-thiet-bi', canQuyen('quyen-loi:xu-ly'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaGoThietBiQl);
    const d = db(c);
    const bayGio = Date.now();
    const kq = await d.prepare('DELETE FROM quyen_loi_devices WHERE entitlement_id = ? AND device_id = ?').bind(b.id, b.thietBi).run();
    if ((kq.meta.changes ?? 0) === 0) throw new LoiApi(404, 'khong-thay');
    await d
      .prepare('INSERT INTO quyen_loi_events (id, entitlement_id, kind, detail, ts) VALUES (?, ?, ?, ?, ?)')
      .bind(taoUlid(bayGio), b.id, 'soc-go-thiet-bi', JSON.stringify({ thiet_bi: b.thietBi, boi: email(c) }), bayGio)
      .run();
    await ghiAudit(d, {
      id: taoUlid(bayGio + 1),
      actor: email(c),
      action: 'quyen-loi:go-thiet-bi',
      target: `entitlement:${b.id}`,
      before: { thietBi: b.thietBi },
      after: { lyDo: b.lyDo },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true });
  });

  // Thu hồi thủ công: người thứ nhất đề xuất (lý do + passkey) -> người THỨ HAI duyệt (passkey) mới áp.
  r.post('/quyen-loi/thu-hoi', canQuyen('quyen-loi:xu-ly'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaThuHoiQl);
    const d = db(c);
    const bayGio = Date.now();
    const ql = await d.prepare('SELECT id, state FROM quyen_loi WHERE id = ?').bind(b.id).first<{ id: string; state: string }>();
    if (!ql) throw new LoiApi(404, 'khong-thay');
    kiemThuHoiDuoc(ql.state);
    const id = taoUlid(bayGio);
    try {
      await d.batch([
        // Yêu cầu cũ quá hạn vẫn 'pending' -> huỷ để chỉ mục "một yêu cầu chờ" không chặn đề xuất mới.
        d
          .prepare("UPDATE quyen_loi_requests SET status = 'cancelled', decided_by = created_by, decided_at = ? WHERE entitlement_id = ? AND status = 'pending' AND expires_at <= ?")
          .bind(bayGio, b.id, bayGio),
        d
          .prepare("INSERT INTO quyen_loi_requests (id, entitlement_id, kind, reason, created_by, created_at, expires_at) VALUES (?, ?, 'thu-hoi', ?, ?, ?, ?)")
          .bind(id, b.id, b.lyDo, email(c), bayGio, bayGio + QL_YEU_CAU_HAN_MS),
      ]);
    } catch (e) {
      if (/UNIQUE/i.test(String(e))) throw new LoiApi(409, 'dang-co-yeu-cau');
      throw e;
    }
    await ghiAudit(d, {
      id: taoUlid(bayGio + 1),
      actor: email(c),
      action: 'quyen-loi:de-xuat-thu-hoi',
      target: `entitlement:${b.id}`,
      before: { trangThai: ql.state },
      after: { yeuCau: id, lyDo: b.lyDo },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ yeuCau: id }, 202);
  });

  r.get('/quyen-loi/yeu-cau', canQuyen('quyen-loi:xem'), async (c) => {
    const { results } = await db(c)
      .prepare(
        `SELECT r.id, r.entitlement_id, r.kind, r.reason, r.created_by, r.created_at, r.expires_at, r.status, q.product_id, q.source, q.state
         FROM quyen_loi_requests r JOIN quyen_loi q ON q.id = r.entitlement_id
         WHERE r.status = 'pending' AND r.expires_at > ? ORDER BY r.created_at DESC LIMIT 100`,
      )
      .bind(Date.now())
      .all();
    return c.json({ ds: results, toi: email(c) });
  });

  r.post('/quyen-loi/yeu-cau/quyet', canQuyen('quyen-loi:duyet'), canStepUp, async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaQuyetQl);
    const d = db(c);
    const bayGio = Date.now();
    const yc = await d
      .prepare('SELECT id, entitlement_id, kind, reason, created_by, created_at, expires_at, status FROM quyen_loi_requests WHERE id = ?')
      .bind(b.id)
      .first<DongYeuCau>();
    if (!yc) throw new LoiApi(404, 'khong-thay');
    const toi = email(c);
    kiemQuyet(yc, toi, bayGio);
    // Giành quyền quyết bằng điều kiện status: hai người duyệt cùng lúc -> chỉ một người thắng.
    const kq = await d
      .prepare("UPDATE quyen_loi_requests SET status = ?, decided_by = ?, decided_at = ?, decision_note = ? WHERE id = ? AND status = 'pending'")
      .bind(b.dongY ? 'approved' : 'rejected', toi, bayGio, b.ghiChu ?? null, b.id)
      .run();
    if ((kq.meta.changes ?? 0) === 0) throw new LoiApi(409, 'da-quyet');
    let trangThaiTruoc: string | null = null;
    if (b.dongY && yc.kind === 'thu-hoi') {
      const dong = await d
        .prepare("UPDATE quyen_loi SET state = 'revoked', reason = 'soc', updated_at = ? WHERE id = ? AND state != 'revoked' RETURNING id")
        .bind(bayGio, yc.entitlement_id)
        .first<{ id: string }>();
      trangThaiTruoc = dong ? 'da-ap' : 'da-thu-hoi-truoc';
      await d
        .prepare('INSERT INTO quyen_loi_events (id, entitlement_id, kind, detail, ts) VALUES (?, ?, ?, ?, ?)')
        .bind(taoUlid(bayGio), yc.entitlement_id, 'thu-hoi-soc', JSON.stringify({ yeu_cau: yc.id, de_xuat: yc.created_by, duyet: toi }), bayGio)
        .run();
    }
    await ghiAudit(d, {
      id: taoUlid(bayGio + 1),
      actor: toi,
      action: b.dongY ? 'quyen-loi:duyet-thu-hoi' : 'quyen-loi:bac-thu-hoi',
      target: `entitlement:${yc.entitlement_id}`,
      before: { yeuCau: yc.id, taoBoi: yc.created_by, lyDo: yc.reason },
      after: { ghiChu: b.ghiChu ?? null, ketQua: trangThaiTruoc },
      ip: c.get('ip') || null,
      ts: bayGio,
    });
    return c.json({ ok: true, ketQua: trangThaiTruoc });
  });

  r.post('/quyen-loi/yeu-cau/huy', canQuyen('quyen-loi:xu-ly'), async (c) => {
    canJson(c);
    const b = phanTichBody(await c.req.text(), SchemaHuyQl);
    const d = db(c);
    const bayGio = Date.now();
    const kq = await d
      .prepare("UPDATE quyen_loi_requests SET status = 'cancelled', decided_by = created_by, decided_at = ? WHERE id = ? AND status = 'pending' AND created_by = ?")
      .bind(bayGio, b.id, email(c))
      .run();
    if ((kq.meta.changes ?? 0) === 0) throw new LoiApi(404, 'khong-thay');
    await ghiAudit(d, { id: taoUlid(bayGio), actor: email(c), action: 'quyen-loi:huy-yeu-cau', target: `approval:${b.id}`, before: null, after: null, ip: c.get('ip') || null, ts: bayGio });
    return c.json({ ok: true });
  });
}
