// Mã hoá nhị phân dùng chung cho định danh thiết bị (S2, SEC-ID): base64url, chữ ký ECDSA DER <-> dạng thô JWS,
// chuỗi chuẩn mà thiết bị ký. Hàm thuần - không gọi WebCrypto.

export function b64urlTuByte(b: ArrayBuffer | Uint8Array): string {
  let s = '';
  for (const x of b instanceof Uint8Array ? b : new Uint8Array(b)) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** base64url (không đệm) -> byte; sai ký tự / độ dài -> null. */
export function byteTuB64url(s: string): Uint8Array<ArrayBuffer> | null {
  if (!/^[A-Za-z0-9_-]*$/.test(s) || s.length % 4 === 1) return null;
  const nhiPhan = atob(s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4));
  const b = new Uint8Array(nhiPhan.length);
  for (let i = 0; i < nhiPhan.length; i++) b[i] = nhiPhan.charCodeAt(i);
  return b;
}

export function b64urlTuChuoi(s: string): string {
  return b64urlTuByte(new TextEncoder().encode(s));
}

/** Chuỗi hex thường; base64 / base64url của 32 byte cũng nhận (Play Integrity trả digest chứng chỉ dạng base64url). */
export function digestSangHex(s: string): string | null {
  const t = s.replace(/:/g, '').toLowerCase();
  if (/^[0-9a-f]{64}$/.test(t)) return t;
  const b = byteTuB64url(s.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''));
  if (!b || b.length !== 32) return null;
  return [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
}

/**
 * Chữ ký ECDSA P-256 dạng DER (Android `SHA256withECDSA`) -> 64 byte r||s (dạng WebCrypto / JWS). Sai cấu trúc -> null.
 * DER: 30 len 02 lr r 02 ls s; r, s có thể có byte 0x00 dẫn đầu (số dương) hoặc ngắn hơn 32 byte.
 */
export function derSangTho(der: Uint8Array): Uint8Array<ArrayBuffer> | null {
  if (der.length < 8 || der.length > 72 || der[0] !== 0x30 || der[1] !== der.length - 2) return null;
  const ra = new Uint8Array(64);
  let i = 2;
  for (const viTri of [0, 32]) {
    if (der[i] !== 0x02) return null;
    const dai = der[i + 1] ?? 0;
    if (dai < 1 || dai > 33 || i + 2 + dai > der.length) return null;
    let so = der.subarray(i + 2, i + 2 + dai);
    if (so.length === 33) {
      if (so[0] !== 0) return null;
      so = so.subarray(1);
    }
    ra.set(so, viTri + 32 - so.length);
    i += 2 + dai;
  }
  return i === der.length ? ra : null;
}

/** Tiền tố phân miền: chữ ký cho mục đích này không dùng lại được cho mục đích khác. */
export const MIEN_KY = { dangKy: 'la-ban/v1/dang-ky', xacThuc: 'la-ban/v1/xac-thuc', lamMoi: 'la-ban/v1/lam-moi' } as const;

/** Chuỗi thiết bị ký khi đăng ký; cũng là nguồn của requestHash gửi Play Integrity (gắn token với khoá + thách thức). */
export function chuoiDangKy(thachThuc: string, installationId: string, khoaCongKhai: string): string {
  return `${MIEN_KY.dangKy}\n${thachThuc}\n${installationId}\n${khoaCongKhai}`;
}

export function chuoiXacThuc(thachThuc: string, thietBiId: string): string {
  return `${MIEN_KY.xacThuc}\n${thachThuc}\n${thietBiId}`;
}

export function chuoiLamMoi(refreshToken: string, ts: number, nonce: string): string {
  return `${MIEN_KY.lamMoi}\n${refreshToken}\n${ts}\n${nonce}`;
}
