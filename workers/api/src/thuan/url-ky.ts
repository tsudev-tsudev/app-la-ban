// SH-05: tài nguyên qua URL KÝ có hạn - `/v1/tn/<khoá>?het=<ms>&ky=<HMAC-SHA256 base64url>`. Khoá bí mật `KHOA_URL_KY`
// (wrangler secret) chỉ Worker giữ; admin (S6) xin URL ký từ API thay vì nhận đường dẫn R2 trần. Chặn hotlink theo
// Referer / Sec-Fetch-Site: trang ngoài danh sách nhúng tài nguyên -> 403.

/** Hạn tối đa của một URL ký (ms) - URL lộ ra ngoài chỉ sống tối đa chừng này. */
export const HAN_TOI_DA_MS = 7 * 24 * 3_600_000;

const MAU_KHOA = /^[a-z0-9][a-z0-9_.-]*(\/[a-z0-9][a-z0-9_.-]*){0,7}$/;

export function khoaHopLe(khoa: string): boolean {
  return khoa.length <= 200 && MAU_KHOA.test(khoa) && !khoa.split('/').some((p) => p === '.' || p === '..');
}

function b64url(b: ArrayBuffer): string {
  let s = '';
  for (const x of new Uint8Array(b)) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function giaiB64url(s: string): Uint8Array<ArrayBuffer> | null {
  if (!/^[A-Za-z0-9_-]{43}$/.test(s)) return null;
  const nhiPhan = atob(s.replace(/-/g, '+').replace(/_/g, '/') + '=');
  const b = new Uint8Array(nhiPhan.length);
  for (let i = 0; i < nhiPhan.length; i++) b[i] = nhiPhan.charCodeAt(i);
  return b;
}

function nhapKhoa(biMat: string, dung: ('sign' | 'verify')[]): Promise<CryptoKey> {
  return crypto.subtle.importKey('raw', new TextEncoder().encode(biMat), { name: 'HMAC', hash: 'SHA-256' }, false, dung);
}

const thongDiep = (khoa: string, het: number) => new TextEncoder().encode(`tn\n${khoa}\n${het}`);

export async function kyUrl(biMat: string, khoa: string, het: number): Promise<string> {
  if (!khoaHopLe(khoa)) throw new Error('khoá tài nguyên sai dạng');
  const k = await nhapKhoa(biMat, ['sign']);
  const ky = b64url(await crypto.subtle.sign('HMAC', k, thongDiep(khoa, het)));
  return `/v1/tn/${khoa}?het=${het}&ky=${ky}`;
}

export type KetQuaKiemUrl = 'ok' | 'het-han' | 'sai';

/** So chữ ký bằng `subtle.verify` (thời gian hằng). Hạn quá xa (> HAN_TOI_DA_MS) coi như sai - không có URL vĩnh viễn. */
export async function kiemUrl(biMat: string, khoa: string, hetStr: string | undefined, ky: string | undefined, bayGio: number): Promise<KetQuaKiemUrl> {
  if (!khoaHopLe(khoa) || !hetStr || !/^\d{1,15}$/.test(hetStr) || !ky) return 'sai';
  const het = Number(hetStr);
  const chuKy = giaiB64url(ky);
  if (!chuKy || het > bayGio + HAN_TOI_DA_MS) return 'sai';
  const k = await nhapKhoa(biMat, ['verify']);
  if (!(await crypto.subtle.verify('HMAC', k, chuKy, thongDiep(khoa, het)))) return 'sai';
  return het <= bayGio ? 'het-han' : 'ok';
}

/**
 * Hotlink: Referer từ origin ngoài danh sách -> chặn; không Referer thì chỉ chặn khi trình duyệt báo `cross-site`
 * (trang của mình đặt Referrer-Policy chặt nên có thể không gửi Referer).
 */
export function laHotlink(secFetchSite: string | undefined, referer: string | undefined, nguonChoPhep: readonly string[]): boolean {
  if (referer) {
    try {
      return !nguonChoPhep.includes(new URL(referer).origin);
    } catch {
      return true;
    }
  }
  return secFetchSite === 'cross-site';
}

/** Cache trình duyệt không vượt hạn URL (và tối đa 1 giờ). */
export function maxAgeGiay(het: number, bayGio: number): number {
  return Math.max(0, Math.min(3600, Math.floor((het - bayGio) / 1000)));
}
