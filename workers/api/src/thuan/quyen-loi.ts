// Quyền lợi Pro (M1a bước 3, QUYET_DINH Q55 / Q56, SEC-IAP) - hàm thuần: đọc phản hồi Google Play Developer API,
// RTDN (Pub/Sub push), JWT OIDC của Google, gộp quyền lợi cho /v1/status, mã hoá purchase token. Không I/O.
import { z } from 'zod';
import { b64urlTuByte, byteTuB64url } from './ma-hoa';

/** Sản phẩm Play đã chốt (Q55): hai gói đăng ký + một sản phẩm mua một lần. */
export const SAN_PHAM = { pro_thang: 'sub', pro_nam: 'sub', pro_vinh_vien: 'inapp' } as const;
export type SanPham = keyof typeof SAN_PHAM;
export const DS_SAN_PHAM = Object.keys(SAN_PHAM) as [SanPham, ...SanPham[]];

export const TRANG_THAI_QL = ['active', 'grace', 'canceled', 'on_hold', 'paused', 'pending', 'expired', 'revoked'] as const;
export type TrangThaiQl = (typeof TRANG_THAI_QL)[number];

/** Mặc định IAP-04: một token tối đa 5 cài đặt hoạt động trong 30 ngày. */
export const THIET_BI_TOI_DA_MAC_DINH = 5;
export const CUA_SO_HOAT_DONG_MS = 30 * 24 * 60 * 60 * 1000;

/** Purchase token của Play: chữ, số, `.`, `-`, `_` (thực tế ~150-500 ký tự). */
export const schemaPurchaseToken = z.string().regex(/^[A-Za-z0-9._-]{16,2048}$/);

const chuoiSo = z.union([z.string().regex(/^\d{1,16}$/), z.number().int().nonnegative()]).transform(Number);

// Google có thể thêm trường -> object thường (không strict), chỉ kiểm phần dùng tới.
export const schemaGoiDangKy = z.object({
  subscriptionState: z.string().max(64),
  latestOrderId: z.string().max(128).optional(),
  acknowledgementState: z.string().max(64).optional(),
  linkedPurchaseToken: z.string().max(2048).optional(),
  testPurchase: z.object({}).optional(),
  externalAccountIdentifiers: z.object({ obfuscatedExternalAccountId: z.string().max(128).optional() }).optional(),
  lineItems: z
    .array(
      z.object({
        productId: z.string().max(128),
        expiryTime: z.string().max(64).optional(),
        autoRenewingPlan: z.object({ autoRenewEnabled: z.boolean().optional() }).optional(),
      }),
    )
    .max(10)
    .default([]),
});
export type GoiDangKy = z.infer<typeof schemaGoiDangKy>;

export const schemaMuaMotLan = z.object({
  /** 0 đã mua, 1 đã huỷ (hoàn tiền), 2 chờ thanh toán. */
  purchaseState: z.number().int().optional(),
  /** 0 chưa xác nhận, 1 đã xác nhận. */
  acknowledgementState: z.number().int().optional(),
  orderId: z.string().max(128).optional(),
  /** 0 = mua thử của license tester. */
  purchaseType: z.number().int().optional(),
  obfuscatedExternalAccountId: z.string().max(128).optional(),
  productId: z.string().max(128).optional(),
});
export type MuaMotLan = z.infer<typeof schemaMuaMotLan>;

export type KetQuaXacMinh = {
  trangThai: TrangThaiQl;
  /** ms; null = không hết hạn (mua vĩnh viễn). */
  hetHan: number | null;
  tuDongGiaHan: boolean | null;
  daXacNhan: boolean;
  maDon: string | null;
  thu: boolean;
  taiKhoan: string | null;
  tokenLienKet: string | null;
};

const TRANG_THAI_GOI: Record<string, TrangThaiQl> = {
  SUBSCRIPTION_STATE_ACTIVE: 'active',
  SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'grace',
  SUBSCRIPTION_STATE_CANCELED: 'canceled',
  SUBSCRIPTION_STATE_ON_HOLD: 'on_hold',
  SUBSCRIPTION_STATE_PAUSED: 'paused',
  SUBSCRIPTION_STATE_PENDING: 'pending',
  SUBSCRIPTION_STATE_EXPIRED: 'expired',
  SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: 'expired',
};

/** purchases.subscriptionsv2 -> trạng thái. Không có dòng của [sanPham] -> null (token thuộc sản phẩm khác). */
export function docGoiDangKy(g: GoiDangKy, sanPham: string): KetQuaXacMinh | null {
  const dong = g.lineItems.find((l) => l.productId === sanPham);
  if (!dong) return null;
  const het = dong.expiryTime ? Date.parse(dong.expiryTime) : NaN;
  return {
    trangThai: TRANG_THAI_GOI[g.subscriptionState] ?? 'pending',
    hetHan: Number.isFinite(het) ? het : 0,
    tuDongGiaHan: dong.autoRenewingPlan?.autoRenewEnabled ?? null,
    daXacNhan: g.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
    maDon: g.latestOrderId ?? null,
    thu: g.testPurchase !== undefined,
    taiKhoan: g.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null,
    tokenLienKet: g.linkedPurchaseToken ?? null,
  };
}

/** purchases.products -> trạng thái. productId lệch -> null. */
export function docMuaMotLan(m: MuaMotLan, sanPham: string): KetQuaXacMinh | null {
  if (m.productId !== undefined && m.productId !== sanPham) return null;
  const trangThai: TrangThaiQl = m.purchaseState === 0 ? 'active' : m.purchaseState === 2 ? 'pending' : 'revoked';
  return {
    trangThai,
    hetHan: null,
    tuDongGiaHan: null,
    daXacNhan: m.acknowledgementState === 1,
    maDon: m.orderId ?? null,
    thu: m.purchaseType === 0,
    taiKhoan: m.obfuscatedExternalAccountId ?? null,
    tokenLienKet: null,
  };
}

/** Quyền lợi đang có hiệu lực: đang chạy / ân hạn / đã huỷ gia hạn nhưng còn hạn. */
export function conHieuLuc(trangThai: string, hetHan: number | null, bayGio: number): boolean {
  if (trangThai !== 'active' && trangThai !== 'grace' && trangThai !== 'canceled') return false;
  return hetHan === null || hetHan > bayGio;
}

export type QuyenLoiTraVe = { pro: boolean; khongQuangCao: boolean; hetHan: number | null };

/** Gộp các dòng quyền lợi của thiết bị -> phần `quyenLoi` của /v1/status. hetHan null + pro = vĩnh viễn. */
export function tongHopQuyenLoi(ds: readonly { state: string; expires_at: number | null }[], bayGio: number): QuyenLoiTraVe {
  const con = ds.filter((d) => conHieuLuc(d.state, d.expires_at, bayGio));
  if (!con.length) return { pro: false, khongQuangCao: false, hetHan: null };
  const vinhVien = con.some((d) => d.expires_at === null);
  return { pro: true, khongQuangCao: true, hetHan: vinhVien ? null : Math.max(...con.map((d) => d.expires_at as number)) };
}

/** Trạng thái mới khi ghi đè dòng cũ: đã thu hồi (hoàn tiền / SOC) thì Google không "mở lại" được. */
export function trangThaiGhiDe(cu: string | null, moi: TrangThaiQl): TrangThaiQl {
  return cu === 'revoked' ? 'revoked' : moi;
}

// --- RTDN (Real-time developer notifications) qua Pub/Sub push ---

export const schemaDayPubSub = z.object({
  message: z.object({
    data: z.string().max(16_384),
    messageId: z.string().max(128).optional(),
  }),
  subscription: z.string().max(512).optional(),
});

const schemaRtdn = z.object({
  packageName: z.string().max(255),
  eventTimeMillis: chuoiSo.optional(),
  subscriptionNotification: z
    .object({ notificationType: z.number().int(), purchaseToken: schemaPurchaseToken, subscriptionId: z.string().max(128) })
    .optional(),
  oneTimeProductNotification: z
    .object({ notificationType: z.number().int(), purchaseToken: schemaPurchaseToken, sku: z.string().max(128) })
    .optional(),
  voidedPurchaseNotification: z
    .object({ purchaseToken: schemaPurchaseToken, orderId: z.string().max(128).optional(), productType: z.number().int().optional() })
    .optional(),
  testNotification: z.object({}).optional(),
});

export type ViecRtdn =
  | { loai: 'sub'; goi: string; token: string; sanPham: string; kieu: number }
  | { loai: 'inapp'; goi: string; token: string; sanPham: string; kieu: number }
  | { loai: 'hoan'; goi: string; token: string }
  | { loai: 'thu'; goi: string }
  | { loai: 'bo'; lyDo: string };

function giaiBase64(s: string): string | null {
  try {
    const nhiPhan = atob(s);
    const b = Uint8Array.from(nhiPhan, (k) => k.charCodeAt(0));
    return new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(b);
  } catch {
    return null;
  }
}

/** `message.data` (base64 chuẩn) -> việc cần làm. Gói không thuộc danh sách / sản phẩm lạ -> 'bo' (vẫn trả 2xx cho Pub/Sub). */
export function docRtdn(data: string, dsGoi: readonly string[]): ViecRtdn {
  const vb = giaiBase64(data);
  if (vb === null) return { loai: 'bo', lyDo: 'base64' };
  let tho: unknown;
  try {
    tho = JSON.parse(vb);
  } catch {
    return { loai: 'bo', lyDo: 'json' };
  }
  const kq = schemaRtdn.safeParse(tho);
  if (!kq.success) return { loai: 'bo', lyDo: 'dang' };
  const r = kq.data;
  if (!dsGoi.includes(r.packageName)) return { loai: 'bo', lyDo: 'goi' };
  if (r.voidedPurchaseNotification) return { loai: 'hoan', goi: r.packageName, token: r.voidedPurchaseNotification.purchaseToken };
  if (r.subscriptionNotification) {
    const n = r.subscriptionNotification;
    if (SAN_PHAM[n.subscriptionId as SanPham] !== 'sub') return { loai: 'bo', lyDo: 'san-pham' };
    return { loai: 'sub', goi: r.packageName, token: n.purchaseToken, sanPham: n.subscriptionId, kieu: n.notificationType };
  }
  if (r.oneTimeProductNotification) {
    const n = r.oneTimeProductNotification;
    if (SAN_PHAM[n.sku as SanPham] !== 'inapp') return { loai: 'bo', lyDo: 'san-pham' };
    return { loai: 'inapp', goi: r.packageName, token: n.purchaseToken, sanPham: n.sku, kieu: n.notificationType };
  }
  if (r.testNotification) return { loai: 'thu', goi: r.packageName };
  return { loai: 'bo', lyDo: 'khong-loai' };
}

// --- JWT OIDC của Google (Pub/Sub push có xác thực, IAP-02) ---

export type LoiOidc = 'thieu' | 'dinh-dang' | 'kid' | 'chu-ky' | 'iss' | 'aud' | 'het-han' | 'email';

export class LoiJwtGoogle extends Error {
  constructor(readonly ma: LoiOidc) {
    super(ma);
  }
}

const LECH_GIAY = 60;
const ISS_GOOGLE = new Set(['https://accounts.google.com', 'accounts.google.com']);

function phanJson(phan: string): Record<string, unknown> {
  const b = byteTuB64url(phan);
  if (!b) throw new LoiJwtGoogle('dinh-dang');
  try {
    const v: unknown = JSON.parse(new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(b));
    if (typeof v !== 'object' || v === null || Array.isArray(v)) throw new Error();
    return v as Record<string, unknown>;
  } catch {
    throw new LoiJwtGoogle('dinh-dang');
  }
}

/** Kiểm JWT của Pub/Sub: RS256 theo JWKS Google, iss, aud đúng route, email = service account đẩy, email_verified, hạn. */
export async function kiemJwtGoogle(
  token: string | null | undefined,
  dsKhoa: readonly JsonWebKey[],
  p: { aud: string; email: string; bayGioGiay: number },
): Promise<void> {
  if (!token) throw new LoiJwtGoogle('thieu');
  if (token.length > 8192) throw new LoiJwtGoogle('dinh-dang');
  const phan = token.split('.');
  if (phan.length !== 3) throw new LoiJwtGoogle('dinh-dang');
  const [dau, than, ky] = phan as [string, string, string];
  const h = phanJson(dau);
  if (h.alg !== 'RS256') throw new LoiJwtGoogle('dinh-dang');
  const khoa = dsKhoa.find((k) => (k as { kid?: string }).kid === h.kid && k.kty === 'RSA');
  if (!khoa?.n || !khoa.e) throw new LoiJwtGoogle('kid');
  const chuKy = byteTuB64url(ky);
  if (!chuKy) throw new LoiJwtGoogle('dinh-dang');
  const k = await crypto.subtle.importKey('jwk', { kty: 'RSA', n: khoa.n, e: khoa.e }, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, [
    'verify',
  ]);
  if (!(await crypto.subtle.verify('RSASSA-PKCS1-v1_5', k, chuKy, new TextEncoder().encode(`${dau}.${than}`)))) {
    throw new LoiJwtGoogle('chu-ky');
  }
  const c = phanJson(than);
  if (typeof c.iss !== 'string' || !ISS_GOOGLE.has(c.iss)) throw new LoiJwtGoogle('iss');
  if (c.aud !== p.aud) throw new LoiJwtGoogle('aud');
  const exp = typeof c.exp === 'number' ? c.exp : 0;
  if (exp + LECH_GIAY < p.bayGioGiay) throw new LoiJwtGoogle('het-han');
  if (typeof c.iat === 'number' && c.iat - LECH_GIAY > p.bayGioGiay) throw new LoiJwtGoogle('het-han');
  if (typeof c.email !== 'string' || c.email.toLowerCase() !== p.email.toLowerCase() || c.email_verified !== true) {
    throw new LoiJwtGoogle('email');
  }
}

/** Đọc kid từ header JWT (chọn khoá / quyết định nạp lại JWKS) - không kiểm. */
export function kidJwt(token: string): string | null {
  try {
    const h = phanJson(token.split('.')[0] ?? '');
    return typeof h.kid === 'string' ? h.kid : null;
  } catch {
    return null;
  }
}

// --- Mã hoá purchase token (IAP-03): AES-GCM 256, khoá base64 32 byte ở wrangler secret KHOA_QUYEN_LOI ---

const AAD = new TextEncoder().encode('la-ban/quyen-loi/v1');

async function nhapKhoa(khoaB64: string): Promise<CryptoKey> {
  let tho: Uint8Array<ArrayBuffer>;
  try {
    tho = Uint8Array.from(atob(khoaB64.trim()), (k) => k.charCodeAt(0));
  } catch {
    throw new Error('khoa-quyen-loi-sai-dang');
  }
  if (tho.length !== 32) throw new Error('khoa-quyen-loi-sai-do-dai');
  return crypto.subtle.importKey('raw', tho, 'AES-GCM', false, ['encrypt', 'decrypt']);
}

/** -> `v1.<iv b64url>.<bản mã b64url>`. */
export async function maHoaToken(khoaB64: string, token: string): Promise<string> {
  const khoa = await nhapKhoa(khoaB64);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ma = await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: AAD }, khoa, new TextEncoder().encode(token));
  return `v1.${b64urlTuByte(iv)}.${b64urlTuByte(ma)}`;
}

/** Giải mã; sai khoá / sửa bản mã / sai định dạng -> null. */
export async function giaiMaTokenQl(khoaB64: string, banMa: string): Promise<string | null> {
  const [phienBan, ivB, maB] = banMa.split('.');
  if (phienBan !== 'v1' || !ivB || !maB) return null;
  const iv = byteTuB64url(ivB);
  const ma = byteTuB64url(maB);
  if (!iv || !ma || iv.length !== 12) return null;
  try {
    const khoa = await nhapKhoa(khoaB64);
    const ro = await crypto.subtle.decrypt({ name: 'AES-GCM', iv, additionalData: AAD }, khoa, ma);
    return new TextDecoder().decode(ro);
  } catch {
    return null;
  }
}
