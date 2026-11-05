// M1a bước 3 (QUYET_DINH Q55 / Q56, SEC-IAP) - quyền lợi Pro phía máy chủ:
//   POST /v1/mua/xac-minh  (phiên + chữ ký)  app gửi purchase token -> Worker hỏi Google -> D1 quyen_loi -> quyenLoi
//   POST /v1/play/rtdn     (JWT OIDC Google)  Pub/Sub push RTDN: gia hạn / huỷ / tạm giữ / hoàn tiền
//   cron hằng ngày: Voided Purchases -> thu hồi; xác minh lại gói đăng ký sắp / vừa hết hạn (lỡ RTDN)
//   quyenLoiThietBi(): phần `quyenLoi` của /v1/status (đã ký) · capNhatProApp(): app Pro LICENSED -> `pro_app` (Q56)
// Client KHÔNG tự mở khoá từ kết quả Billing Library (IAP-01) - chỉ hiển thị theo /v1/status.
import { z } from 'zod';
import { LoiDichVu } from './attest/google';
import type { Env, Ngu } from './moi-truong';
import { baoSuKien, nen } from './mw/dich-vu';
import { ghiLog } from './mw/ghi-log';
import { dsMuaBiHuy, layGoiDangKy, layMuaMotLan, xacNhanMua } from './mua-google';
import { tachDs } from './thuan/access-jwt';
import { sha256Hex } from './thuan/bam';
import { taoUlid } from './thuan/dinh-danh';
import { LoiApi } from './thuan/loi';
import {
  CUA_SO_HOAT_DONG_MS,
  DS_SAN_PHAM,
  SAN_PHAM,
  THIET_BI_TOI_DA_MAC_DINH,
  docGoiDangKy,
  docMuaMotLan,
  docRtdn,
  giaiMaTokenQl,
  goiBanTrongApp,
  kidJwt,
  kiemJwtGoogle,
  LoiJwtGoogle,
  maHoaToken,
  schemaDayPubSub,
  schemaPurchaseToken,
  tongHopQuyenLoi,
  type KetQuaXacMinh,
  type QuyenLoiTraVe,
} from './thuan/quyen-loi';
import { diemDoanhThu, rtdnCoThuTien, type SuKienDoanhThu } from './thuan/quyen-loi-soc';
import type { BoTuyen } from './tuyen';

const NGAY_MS = 24 * 60 * 60 * 1000;
const KHONG_PRO: QuyenLoiTraVe = { pro: false, khongQuangCao: false, hetHan: null };

export const schemaQuyenLoi = z.object({ pro: z.boolean(), khongQuangCao: z.boolean(), hetHan: z.number().int().nullable() });

function canDb(env: Env): D1Database {
  if (!env.DB) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'DB' });
  return env.DB;
}

function canKhoa(env: Env): string {
  if (!env.KHOA_QUYEN_LOI) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'KHOA_QUYEN_LOI' });
  return env.KHOA_QUYEN_LOI;
}

function thietBiToiDa(env: Env): number {
  const n = Number(env.QL_THIET_BI_TOI_DA);
  return Number.isInteger(n) && n >= 1 && n <= 50 ? n : THIET_BI_TOI_DA_MAC_DINH;
}

async function ghiSuKienQl(db: D1Database, id: string | null, loai: string, chiTiet: Record<string, unknown>, bayGio: number): Promise<void> {
  await db
    .prepare('INSERT INTO quyen_loi_events (id, entitlement_id, kind, detail, ts) VALUES (?, ?, ?, ?, ?)')
    .bind(taoUlid(bayGio), id, loai, JSON.stringify(chiTiet).slice(0, 2000), bayGio)
    .run();
}

/** M1a bước 5: điểm AE cho doanh thu ước tính trên SOC (sản phẩm + loại sự kiện, không token / thiết bị / tài khoản). */
function ghiDoanhThu(env: Env, sanPham: string, suKien: SuKienDoanhThu, thu: boolean): void {
  env.SU_KIEN?.writeDataPoint(diemDoanhThu(sanPham, suKien, thu));
}

/** Ghi / cập nhật quyền lợi theo băm token (một token = một dòng). Đã thu hồi thì giữ thu hồi. Trả id dòng + dòng mới tạo. */
async function ghiQuyenLoi(
  env: Env,
  db: D1Database,
  p: { loai: 'sub' | 'inapp'; goi: string; sanPham: string; token: string; kq: KetQuaXacMinh; bayGio: number },
): Promise<{ id: string; moi: boolean }> {
  const khoa = canKhoa(env);
  const bam = await sha256Hex(p.token);
  const dong = await db
    .prepare(
      `INSERT INTO quyen_loi (id, source, package_name, product_id, state, expires_at, token_hash, token_enc, order_id, account_hash,
         auto_renew, acknowledged, test_purchase, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT (token_hash) WHERE token_hash IS NOT NULL DO UPDATE SET
         state = CASE WHEN quyen_loi.state = 'revoked' THEN 'revoked' ELSE excluded.state END,
         expires_at = excluded.expires_at, token_enc = excluded.token_enc,
         order_id = coalesce(excluded.order_id, quyen_loi.order_id), account_hash = coalesce(excluded.account_hash, quyen_loi.account_hash),
         auto_renew = excluded.auto_renew, acknowledged = max(quyen_loi.acknowledged, excluded.acknowledged),
         test_purchase = excluded.test_purchase, updated_at = excluded.updated_at
       RETURNING id, created_at`,
    )
    .bind(
      taoUlid(p.bayGio),
      p.loai === 'sub' ? 'play_sub' : 'play_inapp',
      p.goi,
      p.sanPham,
      p.kq.trangThai,
      p.kq.hetHan,
      bam,
      await maHoaToken(khoa, p.token),
      p.kq.maDon,
      p.kq.taiKhoan,
      p.kq.tuDongGiaHan === null ? null : Number(p.kq.tuDongGiaHan),
      Number(p.kq.daXacNhan),
      Number(p.kq.thu),
      p.bayGio,
      p.bayGio,
    )
    .first<{ id: string; created_at: number }>();
  if (!dong) throw new Error('không ghi được quyền lợi');
  // ON CONFLICT giữ created_at cũ -> chỉ dòng vừa chèn có created_at = bayGio.
  const moi = dong.created_at === p.bayGio;
  if (moi && (p.kq.trangThai === 'active' || p.kq.trangThai === 'grace')) ghiDoanhThu(env, p.sanPham, 'mua-moi', p.kq.thu);
  return { id: dong.id, moi };
}

/** Thu hồi theo purchase token (hoàn tiền / chargeback / thay bằng gói nâng cấp). Trả id nếu có dòng. */
async function thuHoiTheoToken(env: Env, db: D1Database, token: string, lyDo: string, bayGio: number): Promise<string | null> {
  const dong = await db
    .prepare("UPDATE quyen_loi SET state = 'revoked', reason = ?, updated_at = ? WHERE token_hash = ? AND state != 'revoked' RETURNING id, product_id, test_purchase")
    .bind(lyDo, bayGio, await sha256Hex(token))
    .first<{ id: string; product_id: string; test_purchase: number }>();
  if (dong) await ghiSuKienQl(db, dong.id, 'thu-hoi', { ly_do: lyDo }, bayGio);
  if (dong && lyDo === 'hoan-tien') ghiDoanhThu(env, dong.product_id, 'hoan', dong.test_purchase === 1);
  return dong?.id ?? null;
}

/** Hỏi Google trạng thái token. null = token không tồn tại / không khớp sản phẩm. LoiDichVu khi Google lỗi. */
async function hoiGoogle(env: Env, loai: 'sub' | 'inapp', goi: string, sanPham: string, token: string): Promise<KetQuaXacMinh | null> {
  if (loai === 'sub') {
    const g = await layGoiDangKy(env, goi, token);
    return g ? docGoiDangKy(g, sanPham) : null;
  }
  const m = await layMuaMotLan(env, goi, sanPham, token);
  return m ? docMuaMotLan(m, sanPham) : null;
}

const canXacNhan = (kq: KetQuaXacMinh) => !kq.daXacNhan && (kq.trangThai === 'active' || kq.trangThai === 'grace');

async function xacNhanNen(env: Env, db: D1Database, id: string, p: { loai: 'sub' | 'inapp'; goi: string; sanPham: string; token: string }): Promise<void> {
  if (await xacNhanMua(env, p.goi, p.loai, p.sanPham, p.token)) {
    await db.prepare('UPDATE quyen_loi SET acknowledged = 1 WHERE id = ?').bind(id).run();
  }
}

/** Phần `quyenLoi` của /v1/status. D1 lỗi -> không Pro (app giữ bản đệm có ân hạn offline - M1a bước 2). */
export async function quyenLoiThietBi(db: D1Database | undefined, thietBi: string, bayGio: number): Promise<QuyenLoiTraVe> {
  if (!db) return KHONG_PRO;
  try {
    const { results } = await db
      .prepare('SELECT q.state, q.expires_at FROM quyen_loi_devices d JOIN quyen_loi q ON q.id = d.entitlement_id WHERE d.device_id = ?')
      .bind(thietBi)
      .all<{ state: string; expires_at: number | null }>();
    return tongHopQuyenLoi(results, bayGio);
  } catch (e) {
    ghiLog('error', 'quyen-loi-doc-loi', { loi: String(e).slice(0, 200) });
    return KHONG_PRO;
  }
}

/**
 * App Pro (Q56): phán quyết Play Integrity của gói Pro có `appLicensingVerdict` LICENSED (bản tải từ Play) -> quyền lợi
 * `pro_app` gắn thiết bị; UNLICENSED (bản sao tải ngoài) -> thu hồi + tín hiệu PRO_UNLICENSED (0 điểm, không ban - IAP-05).
 * UNEVALUATED / thiếu -> giữ nguyên.
 */
export async function capNhatProApp(c: Ngu, thietBi: string, goi: string, tinHieu: Record<string, unknown>): Promise<void> {
  const db = c.env.DB;
  if (!db || !tachDs(c.env.PI_GOI_PRO).includes(goi)) return;
  const bayGio = Date.now();
  const id = `pro_app:${thietBi}`;
  if (tinHieu.giay_phep === 'LICENSED' && tinHieu.app === 'PLAY_RECOGNIZED') {
    await db.batch([
      db
        .prepare(
          `INSERT INTO quyen_loi (id, source, package_name, product_id, state, expires_at, acknowledged, created_at, updated_at)
           VALUES (?, 'pro_app', ?, 'pro_app', 'active', NULL, 1, ?, ?)
           ON CONFLICT (id) DO UPDATE SET state = 'active', reason = NULL, updated_at = excluded.updated_at`,
        )
        .bind(id, goi, bayGio, bayGio),
      db
        .prepare('INSERT INTO quyen_loi_devices (entitlement_id, device_id, linked_at, seen_at) VALUES (?, ?, ?, ?) ON CONFLICT (entitlement_id, device_id) DO UPDATE SET seen_at = excluded.seen_at')
        .bind(id, thietBi, bayGio, bayGio),
    ]);
  } else if (tinHieu.giay_phep === 'UNLICENSED') {
    await db.prepare("UPDATE quyen_loi SET state = 'revoked', reason = 'unlicensed', updated_at = ? WHERE id = ?").bind(bayGio, id).run();
    baoSuKien(c, thietBi, 'PRO_UNLICENSED', 'low', { goi });
  }
}

// --- JWKS Google cho JWT OIDC của Pub/Sub ---
const JWKS_GOOGLE = 'https://www.googleapis.com/oauth2/v3/certs';
let boNhoJwks: { khoa: JsonWebKey[]; het: number; napLuc: number } | null = null;

async function napJwksGoogle(kid: string | null): Promise<JsonWebKey[]> {
  const bayGio = Date.now();
  const bn = boNhoJwks;
  const thieuKid = kid !== null && bn !== null && !bn.khoa.some((k) => (k as { kid?: string }).kid === kid);
  if (bn && (thieuKid ? bayGio - bn.napLuc < 30_000 : bayGio < bn.het)) return bn.khoa;
  const res = await fetch(JWKS_GOOGLE, { cf: { cacheTtl: 3600 } } as RequestInit).catch(() => null);
  if (!res?.ok) throw new LoiApi(503, 'google-khong-san-sang', { jwks: res?.status ?? 0 });
  const j = (await res.json()) as { keys?: JsonWebKey[] };
  const khoa = Array.isArray(j.keys) ? j.keys : [];
  boNhoJwks = { khoa, het: bayGio + 60 * 60_000, napLuc: bayGio };
  return khoa;
}

/** Chỉ dùng trong test. */
export function xoaJwksGoogle(): void {
  boNhoJwks = null;
}

export function dangKyMua(boTuyen: BoTuyen): void {
  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/mua/xac-minh',
      tomTat: 'Xác minh giao dịch Play (gói đăng ký / mua một lần) với Google -> quyền lợi Pro của thiết bị',
      body: z.strictObject({ sanPham: z.enum(DS_SAN_PHAM), token: schemaPurchaseToken, goi: z.string().regex(/^[a-z][a-z0-9_.]{2,100}$/) }),
      phanHoi: z.object({ trangThai: z.string(), quyenLoi: schemaQuyenLoi }),
      idempotent: false,
      xacThuc: true,
      gioiHan: [{ chieu: 'thiet-bi', gioiHan: 20, cuaSoMs: 3_600_000 }],
    },
    async (c, b) => {
      const db = canDb(c.env);
      canKhoa(c.env);
      const thietBi = c.get('thietBi') as string;
      if (!goiBanTrongApp(tachDs(c.env.PI_GOI), tachDs(c.env.PI_GOI_PRO)).includes(b.goi)) throw new LoiApi(422, 'goi');
      const loai = SAN_PHAM[b.sanPham];
      const tb = await db.prepare('SELECT attest_signals FROM devices WHERE id = ?').bind(thietBi).first<{ attest_signals: string | null }>();
      // IAP-05: bản không do Play cài (sideload / đóng gói lại) không nhận quyền lợi mới. Staging tắt (bản stg ký debug).
      if (c.env.QL_YEU_CAU_PLAY === '1') {
        let app: unknown;
        try {
          app = (JSON.parse(tb?.attest_signals ?? '{}') as { app?: unknown }).app;
        } catch {
          app = null;
        }
        if (app !== 'PLAY_RECOGNIZED') throw new LoiApi(403, 'khong-phai-ban-play');
      }
      let kq: KetQuaXacMinh | null;
      try {
        kq = await hoiGoogle(c.env, loai, b.goi, b.sanPham, b.token);
      } catch (e) {
        if (!(e instanceof LoiDichVu)) throw e;
        ghiLog('warn', 'play-api-loi', { lyDo: e.lyDo });
        throw new LoiApi(503, 'google-loi', { lyDo: e.lyDo });
      }
      const bayGio = Date.now();
      if (!kq) {
        baoSuKien(c, thietBi, 'PURCHASE_TOKEN_INVALID', 'medium', { san_pham: b.sanPham });
        throw new LoiApi(422, 'token-sai');
      }
      const { id } = await ghiQuyenLoi(c.env, db, { loai, goi: b.goi, sanPham: b.sanPham, token: b.token, kq, bayGio });
      if (kq.tokenLienKet && schemaPurchaseToken.safeParse(kq.tokenLienKet).success) {
        await thuHoiTheoToken(c.env, db, kq.tokenLienKet, 'thay-the', bayGio);
      }
      // IAP-04: một token tối đa N cài đặt hoạt động trong 30 ngày (máy đã gắn thì luôn được làm mới).
      const khac = await db
        .prepare('SELECT count(*) AS n FROM quyen_loi_devices WHERE entitlement_id = ? AND device_id != ? AND seen_at > ?')
        .bind(id, thietBi, bayGio - CUA_SO_HOAT_DONG_MS)
        .first<{ n: number }>();
      const daGan = await db.prepare('SELECT 1 AS c FROM quyen_loi_devices WHERE entitlement_id = ? AND device_id = ?').bind(id, thietBi).first();
      const toiDa = thietBiToiDa(c.env);
      if (!daGan && (khac?.n ?? 0) >= toiDa) {
        baoSuKien(c, thietBi, 'PURCHASE_TOKEN_SHARED', 'high', { so_thiet_bi: (khac?.n ?? 0) + 1, toi_da: toiDa });
        await ghiSuKienQl(db, id, 'tu-choi-chia-se', { so_thiet_bi: (khac?.n ?? 0) + 1 }, bayGio);
        throw new LoiApi(403, 'token-qua-so-thiet-bi');
      }
      await db.batch([
        db
          .prepare('INSERT INTO quyen_loi_devices (entitlement_id, device_id, linked_at, seen_at) VALUES (?, ?, ?, ?) ON CONFLICT (entitlement_id, device_id) DO UPDATE SET seen_at = excluded.seen_at')
          .bind(id, thietBi, bayGio, bayGio),
        db
          .prepare('INSERT INTO quyen_loi_events (id, entitlement_id, kind, detail, ts) VALUES (?, ?, ?, ?, ?)')
          .bind(taoUlid(bayGio), id, 'xac-minh', JSON.stringify({ thiet_bi: thietBi, trang_thai: kq.trangThai, thu: kq.thu }), bayGio),
      ]);
      if (canXacNhan(kq)) nen(c, xacNhanNen(c.env, db, id, { loai, goi: b.goi, sanPham: b.sanPham, token: b.token }), 'xac-nhan-mua');
      return c.json({ trangThai: kq.trangThai, quyenLoi: await quyenLoiThietBi(db, thietBi, bayGio) });
    },
  );

  boTuyen.dangKy(
    {
      phuongThuc: 'post',
      duongDan: '/v1/play/rtdn',
      tomTat: 'Google Play RTDN qua Pub/Sub push (JWT OIDC) - cập nhật gia hạn / huỷ / tạm giữ / hoàn tiền',
      // Pub/Sub có thể thêm trường (deliveryAttempt...) -> object thường, chỉ kiểm phần dùng tới.
      body: schemaDayPubSub,
      phanHoi: z.object({ xuLy: z.string() }),
      idempotent: false,
      bodyToiDa: 32 * 1024,
      gioiHan: [{ chieu: 'ip', gioiHan: 300, cuaSoMs: 60_000 }],
    },
    async (c, b) => {
      const aud = c.env.RTDN_AUD;
      const email = c.env.RTDN_EMAIL;
      if (!aud || !email) throw new LoiApi(503, 'chua-cau-hinh', { thieu: 'RTDN' });
      const token = /^Bearer ([\w.-]+)$/.exec(c.req.header('authorization') ?? '')?.[1] ?? null;
      try {
        await kiemJwtGoogle(token, await napJwksGoogle(token ? kidJwt(token) : null), { aud, email, bayGioGiay: Math.floor(Date.now() / 1000) });
      } catch (e) {
        if (!(e instanceof LoiJwtGoogle)) throw e;
        baoSuKien(c, null, 'RTDN_INVALID', 'medium', { ly_do: e.ma });
        throw new LoiApi(401, 'rtdn-jwt');
      }
      const db = canDb(c.env);
      const viec = docRtdn(b.message.data, goiBanTrongApp(tachDs(c.env.PI_GOI), tachDs(c.env.PI_GOI_PRO)));
      const bayGio = Date.now();
      try {
        if (viec.loai === 'hoan') {
          const id = await thuHoiTheoToken(c.env, db, viec.token, 'hoan-tien', bayGio);
          if (!id) await ghiSuKienQl(db, null, 'rtdn-hoan-khong-dong', {}, bayGio);
        } else if (viec.loai === 'sub' || viec.loai === 'inapp') {
          const kq = await hoiGoogle(c.env, viec.loai, viec.goi, viec.sanPham, viec.token);
          if (!kq) {
            await ghiSuKienQl(db, null, 'rtdn-token-sai', { kieu: viec.kieu }, bayGio);
          } else {
            const p = { loai: viec.loai, goi: viec.goi, sanPham: viec.sanPham, token: viec.token };
            const { id, moi } = await ghiQuyenLoi(c.env, db, { ...p, kq, bayGio });
            if (!moi && viec.loai === 'sub' && rtdnCoThuTien(viec.kieu)) ghiDoanhThu(c.env, viec.sanPham, 'gia-han', kq.thu);
            if (kq.tokenLienKet && schemaPurchaseToken.safeParse(kq.tokenLienKet).success) await thuHoiTheoToken(c.env, db, kq.tokenLienKet, 'thay-the', bayGio);
            await ghiSuKienQl(db, id, 'rtdn', { kieu: viec.kieu, trang_thai: kq.trangThai }, bayGio);
            if (canXacNhan(kq)) nen(c, xacNhanNen(c.env, db, id, p), 'xac-nhan-mua');
          }
        } else if (viec.loai === 'thu') {
          await ghiSuKienQl(db, null, 'rtdn-thu', { goi: viec.goi }, bayGio);
        } else {
          ghiLog('warn', 'rtdn-bo-qua', { lyDo: viec.lyDo });
        }
      } catch (e) {
        // Google lỗi -> 503: Pub/Sub tự gửi lại (backoff), không mất thông báo.
        if (e instanceof LoiDichVu) throw new LoiApi(503, 'google-loi', { lyDo: e.lyDo });
        throw e;
      }
      c.env.SU_KIEN?.writeDataPoint({ indexes: ['rtdn'], blobs: ['rtdn', viec.loai], doubles: [1] });
      return c.json({ xuLy: viec.loai });
    },
  );
}

/**
 * Cron hằng ngày: (1) Voided Purchases 3 ngày gần nhất -> thu hồi (IAP-04: <= 24 h); (2) gói đăng ký còn hiệu lực đã /
 * sắp hết hạn trong 1 ngày -> hỏi lại Google (phòng lỡ RTDN). Lỗi theo từng gói chỉ ghi lại, không ném (app chưa lên Play
 * thì Google trả 403 / 404 mỗi ngày - không báo động giả).
 */
export async function quetQuyenLoi(env: Env, bayGio = Date.now()): Promise<Record<string, unknown>> {
  const db = env.DB;
  if (!db || !env.PLAY_INTEGRITY_SA_JSON || !env.KHOA_QUYEN_LOI) return { boQua: 'chua-cau-hinh' };
  const kq = { thuHoi: 0, kiemLai: 0, loi: [] as string[] };
  for (const goi of goiBanTrongApp(tachDs(env.PI_GOI), tachDs(env.PI_GOI_PRO))) {
    try {
      for (const token of await dsMuaBiHuy(env, goi, bayGio - 3 * NGAY_MS)) {
        if (await thuHoiTheoToken(env, db, token, 'hoan-tien', bayGio)) kq.thuHoi++;
      }
    } catch (e) {
      kq.loi.push(`${goi}:${e instanceof LoiDichVu ? e.lyDo : 'khac'}`);
    }
  }
  const { results } = await db
    .prepare(
      `SELECT id, package_name, product_id, token_enc FROM quyen_loi
       WHERE source = 'play_sub' AND state IN ('active', 'grace', 'canceled', 'on_hold', 'paused') AND expires_at < ? AND token_enc IS NOT NULL
       ORDER BY expires_at LIMIT 50`,
    )
    .bind(bayGio + NGAY_MS)
    .all<{ id: string; package_name: string; product_id: string; token_enc: string }>();
  for (const d of results) {
    const token = await giaiMaTokenQl(env.KHOA_QUYEN_LOI, d.token_enc);
    if (!token) {
      kq.loi.push(`giai-ma:${d.id}`);
      continue;
    }
    try {
      const moi = await hoiGoogle(env, 'sub', d.package_name, d.product_id, token);
      if (moi) {
        await ghiQuyenLoi(env, db, { loai: 'sub', goi: d.package_name, sanPham: d.product_id, token, kq: moi, bayGio });
      } else {
        await db.prepare("UPDATE quyen_loi SET state = 'expired', reason = 'google-khong-thay', updated_at = ? WHERE id = ?").bind(bayGio, d.id).run();
      }
      kq.kiemLai++;
    } catch (e) {
      kq.loi.push(`kiem-lai:${e instanceof LoiDichVu ? e.lyDo : 'khac'}`);
      break;
    }
  }
  return kq;
}
