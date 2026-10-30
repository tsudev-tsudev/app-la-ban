// Kiểm JWT Cloudflare Access (header Cf-Access-Jwt-Assertion) ở Worker - KHÔNG tin chỉ vì request đi qua Access
// (SEC-ADM, Spec §8.1): chữ ký RS256 theo JWKS của team, iss, aud, hạn. Hàm thuần (WebCrypto, không I/O).
import { byteTuB64url } from './ma-hoa';

export type DanhTinhAccess = {
  /** Người dùng đăng nhập qua IdP. Service token không có email. */
  email: string | null;
  /** Client ID của service token (chỉ khi cấu hình cho phép - staging thử e2e). */
  dichVu: string | null;
  sub: string;
  exp: number;
};

export type LoiAccess = 'thieu' | 'dinh-dang' | 'kid' | 'chu-ky' | 'iss' | 'aud' | 'het-han' | 'danh-tinh';

export class LoiJwtAccess extends Error {
  constructor(readonly ma: LoiAccess) {
    super(ma);
  }
}

/** Lệch đồng hồ chấp nhận được giữa Access và Worker. */
const LECH_GIAY = 60;

function json(phan: string): Record<string, unknown> {
  const b = byteTuB64url(phan);
  if (!b) throw new LoiJwtAccess('dinh-dang');
  try {
    const v: unknown = JSON.parse(new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(b));
    if (typeof v !== 'object' || v === null || Array.isArray(v)) throw new Error();
    return v as Record<string, unknown>;
  } catch {
    throw new LoiJwtAccess('dinh-dang');
  }
}

/** Đọc kid từ header mà không kiểm (để chọn khoá trong JWKS). */
export function kidCua(token: string): string | null {
  const dau = token.split('.')[0];
  if (!dau) return null;
  try {
    const h = json(dau);
    return typeof h.kid === 'string' ? h.kid : null;
  } catch {
    return null;
  }
}

export async function kiemJwtAccess(
  token: string | null | undefined,
  dsKhoa: readonly JsonWebKey[],
  p: { team: string; aud: readonly string[]; bayGioGiay: number },
): Promise<DanhTinhAccess> {
  if (!token) throw new LoiJwtAccess('thieu');
  if (token.length > 8192) throw new LoiJwtAccess('dinh-dang');
  const phan = token.split('.');
  if (phan.length !== 3) throw new LoiJwtAccess('dinh-dang');
  const [dau, than, ky] = phan as [string, string, string];
  const h = json(dau);
  if (h.alg !== 'RS256') throw new LoiJwtAccess('dinh-dang');
  const khoa = dsKhoa.find((k) => (k as { kid?: string }).kid === h.kid && k.kty === 'RSA');
  if (!khoa?.n || !khoa.e) throw new LoiJwtAccess('kid');
  const chuKy = byteTuB64url(ky);
  if (!chuKy) throw new LoiJwtAccess('dinh-dang');
  const k = await crypto.subtle.importKey('jwk', { kty: 'RSA', n: khoa.n, e: khoa.e }, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, [
    'verify',
  ]);
  const hopLe = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', k, chuKy, new TextEncoder().encode(`${dau}.${than}`));
  if (!hopLe) throw new LoiJwtAccess('chu-ky');

  const c = json(than);
  if (c.iss !== `https://${p.team}`) throw new LoiJwtAccess('iss');
  const aud = Array.isArray(c.aud) ? c.aud : [c.aud];
  if (!aud.some((a) => typeof a === 'string' && p.aud.includes(a))) throw new LoiJwtAccess('aud');
  const exp = typeof c.exp === 'number' ? c.exp : 0;
  if (exp + LECH_GIAY < p.bayGioGiay) throw new LoiJwtAccess('het-han');
  if (typeof c.nbf === 'number' && c.nbf - LECH_GIAY > p.bayGioGiay) throw new LoiJwtAccess('het-han');
  if (typeof c.iat === 'number' && c.iat - LECH_GIAY > p.bayGioGiay) throw new LoiJwtAccess('het-han');

  const email = typeof c.email === 'string' && /^[^\s@]{1,64}@[^\s@]{1,190}$/.test(c.email) ? chuanHoaEmail(c.email) : null;
  const dichVu = !email && typeof c.common_name === 'string' && c.common_name.length <= 128 ? c.common_name : null;
  if (!email && !dichVu) throw new LoiJwtAccess('danh-tinh');
  return { email, dichVu, sub: typeof c.sub === 'string' ? c.sub : '', exp };
}

const MIEN_GMAIL = new Set(['gmail.com', 'googlemail.com']);

/**
 * Email chuẩn để tra vai trò / phiên / passkey: chữ thường; Gmail bỏ dấu chấm + phần `+nhãn` của tên và gộp googlemail.com
 * (Gmail coi `a.b@gmail.com` = `ab@gmail.com` = `ab+x@gmail.com` cùng một hộp thư - người dùng gõ dạng nào cũng là một người).
 */
export function chuanHoaEmail(email: string): string {
  const e = email.trim().toLowerCase();
  const at = e.lastIndexOf('@');
  if (at < 1) return e;
  const mien = e.slice(at + 1);
  if (!MIEN_GMAIL.has(mien)) return e;
  const ten = e.slice(0, at).split('+')[0]?.replace(/\./g, '') ?? '';
  return ten ? `${ten}@gmail.com` : e;
}

/** Danh sách cấu hình phân tách dấu phẩy -> mảng đã cắt khoảng trắng, bỏ rỗng. */
export function tachDs(s: string | null | undefined): string[] {
  return (s ?? '')
    .split(',')
    .map((x) => x.trim())
    .filter(Boolean);
}
