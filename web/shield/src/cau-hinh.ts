// Cấu hình mức bảo vệ qua gói KÝ SỐ Ed25519 (SEC-WEB-SHIELD). Khoá bí mật nằm NGOÀI repo (tools/cau-hinh/ky-cau-hinh.mjs),
// gói đã ký đặt ở KV `CAU_HINH` và phục vụ nguyên văn bởi `GET /v1/web/cau-hinh`; trang chỉ tin gói có chữ ký khớp khoá
// công khai nhúng trong `khoa.ts`. Mọi lỗi (mạng, sai chữ ký, hết hạn, trình duyệt không có Ed25519) -> giữ mức `chat`.
import { chuanHoaMuc, type MucBaoVe, type Trang } from './muc';

export type GoiCauHinh = { kid: string; duLieu: string; chuKy: string };

export type NoiDungCauHinh = { v: 1; phatHanh: number; het: number; muc: Partial<Record<Trang, MucBaoVe>> };

const B64URL = /^[A-Za-z0-9_-]+$/;
/** Lệch đồng hồ máy người xem chấp nhận được khi so `phatHanh`. */
const LECH_DONG_HO_MS = 24 * 3_600_000;

export function giaiB64url(s: string): Uint8Array<ArrayBuffer> | null {
  if (!B64URL.test(s)) return null;
  try {
    const nhiPhan = atob(s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4));
    const b = new Uint8Array(nhiPhan.length);
    for (let i = 0; i < nhiPhan.length; i++) b[i] = nhiPhan.charCodeAt(i);
    return b;
  } catch {
    return null;
  }
}

export function maB64url(b: Uint8Array): string {
  let s = '';
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function laChuoi(x: unknown, toiDa: number): x is string {
  return typeof x === 'string' && x.length > 0 && x.length <= toiDa;
}

/** Hình dạng gói (chưa kiểm chữ ký). */
export function phanTichGoi(x: unknown): GoiCauHinh | null {
  if (typeof x !== 'object' || x === null) return null;
  const o = x as Record<string, unknown>;
  if (!laChuoi(o.kid, 32) || !laChuoi(o.duLieu, 4096) || !laChuoi(o.chuKy, 128)) return null;
  if (!B64URL.test(o.duLieu) || !B64URL.test(o.chuKy)) return null;
  return { kid: o.kid, duLieu: o.duLieu, chuKy: o.chuKy };
}

/** Nội dung sau khi giải mã (đã kiểm chữ ký). Trường lạ bị bỏ, mức lạ bị bỏ (về mặc định `chat`). */
export function phanTichNoiDung(byte: Uint8Array): NoiDungCauHinh | null {
  let o: unknown;
  try {
    o = JSON.parse(new TextDecoder().decode(byte));
  } catch {
    return null;
  }
  if (typeof o !== 'object' || o === null) return null;
  const r = o as Record<string, unknown>;
  if (r.v !== 1 || !Number.isFinite(r.phatHanh) || !Number.isFinite(r.het)) return null;
  const muc: Partial<Record<Trang, MucBaoVe>> = {};
  if (typeof r.muc === 'object' && r.muc !== null) {
    const m = r.muc as Record<string, unknown>;
    for (const t of ['landing', 'admin'] as const) if (typeof m[t] === 'string') muc[t] = chuanHoaMuc(m[t]);
  }
  return { v: 1, phatHanh: r.phatHanh as number, het: r.het as number, muc };
}

/** Mức cho [trang] từ nội dung đã kiểm; hết hạn / phát hành ở tương lai xa -> `chat`. */
export function mucChoTrang(nd: NoiDungCauHinh | null, trang: Trang, bayGio: number): MucBaoVe {
  if (!nd || bayGio >= nd.het || nd.phatHanh > bayGio + LECH_DONG_HO_MS) return 'chat';
  return nd.muc[trang] ?? 'chat';
}

/** Kiểm chữ ký Ed25519 bằng WebCrypto. Không có khoá cho `kid`, sai chữ ký, trình duyệt thiếu Ed25519 -> null. */
export async function kiemGoi(
  goi: GoiCauHinh,
  khoaCongKhai: Readonly<Record<string, string>>,
  subtle: SubtleCrypto,
): Promise<NoiDungCauHinh | null> {
  const khoa = Object.hasOwn(khoaCongKhai, goi.kid) ? khoaCongKhai[goi.kid] : undefined;
  const raw = khoa ? giaiB64url(khoa) : null;
  const duLieu = giaiB64url(goi.duLieu);
  const chuKy = giaiB64url(goi.chuKy);
  if (!raw || raw.length !== 32 || !duLieu || !chuKy || chuKy.length !== 64) return null;
  try {
    const k = await subtle.importKey('raw', raw, { name: 'Ed25519' }, false, ['verify']);
    if (!(await subtle.verify({ name: 'Ed25519' }, k, chuKy, duLieu))) return null;
  } catch {
    return null;
  }
  return phanTichNoiDung(duLieu);
}
