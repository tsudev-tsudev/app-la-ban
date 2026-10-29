// Phiên thiết bị (SEC-ID ID-04) - hàm thuần: JWT ES256 15 phút gắn khoá thiết bị (cnf.jkt), refresh xoay vòng với
// phát hiện dùng lại. Ký / kiểm chữ ký bằng WebCrypto ở attest/khoa.ts.
import { z } from 'zod';
import { b64urlTuChuoi, byteTuB64url } from './ma-hoa';

export const ACCESS_TTL_MS = 15 * 60 * 1000;
/** Refresh token sống tối đa 30 ngày kể từ lần xoay gần nhất; quá hạn -> đăng ký lại (khoá + thách thức). */
export const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000;
/** Gửi lại cùng refresh token trong khoảng này sau khi xoay (mạng chập chờn, app thử lại) -> 409, KHÔNG thu hồi chuỗi. */
export const AN_HAN_XOAY_MS = 30 * 1000;
/** Chữ ký làm mới: ts lệch giờ server tối đa (SEC-NET). */
export const LECH_TS_MS = 60 * 1000;
export const NHA_PHAT_HANH = 'compass-api';

export const schemaClaim = z.strictObject({
  iss: z.literal(NHA_PHAT_HANH),
  aud: z.string().max(16),
  sub: z.string().max(40),
  sid: z.string().max(40),
  iat: z.number().int(),
  exp: z.number().int(),
  lvl: z.string().max(16),
  cnf: z.strictObject({ jkt: z.string().regex(/^[A-Za-z0-9_-]{43}$/) }),
});
export type ClaimPhien = z.infer<typeof schemaClaim>;

export function taoClaim(p: { moiTruong: string; thietBi: string; phien: string; jkt: string; muc: string; bayGio: number }): ClaimPhien {
  const iat = Math.floor(p.bayGio / 1000);
  return { iss: NHA_PHAT_HANH, aud: p.moiTruong, sub: p.thietBi, sid: p.phien, iat, exp: iat + ACCESS_TTL_MS / 1000, lvl: p.muc, cnf: { jkt: p.jkt } };
}

/** Phần đầu cần ký của JWS (header.payload). */
export function phanKy(kid: string, claim: ClaimPhien): string {
  return `${b64urlTuChuoi(JSON.stringify({ alg: 'ES256', typ: 'JWT', kid }))}.${b64urlTuChuoi(JSON.stringify(claim))}`;
}

export type JwtTach = { kid: string; claim: ClaimPhien; phanKy: string; chuKy: Uint8Array<ArrayBuffer> };

/** Tách + kiểm hình dạng (chưa kiểm chữ ký). Sai dạng / thuật toán khác ES256 -> null. */
export function tachJwt(jwt: string): JwtTach | null {
  if (jwt.length > 2048) return null;
  const phan = jwt.split('.');
  if (phan.length !== 3) return null;
  const [h, p, s] = phan as [string, string, string];
  try {
    const giai = (x: string) => {
      const b = byteTuB64url(x);
      if (!b) throw new Error('b64');
      return JSON.parse(new TextDecoder().decode(b)) as unknown;
    };
    const header = z.strictObject({ alg: z.literal('ES256'), typ: z.literal('JWT'), kid: z.string().max(32) }).safeParse(giai(h));
    const claim = schemaClaim.safeParse(giai(p));
    const chuKy = byteTuB64url(s);
    if (!header.success || !claim.success || !chuKy || chuKy.length !== 64) return null;
    return { kid: header.data.kid, claim: claim.data, phanKy: `${h}.${p}`, chuKy };
  } catch {
    return null;
  }
}

/** Claim còn hiệu lực cho môi trường này ở [bayGio] (cho lệch 30 s ở iat). */
export function claimConHan(c: ClaimPhien, moiTruong: string, bayGio: number): boolean {
  const s = bayGio / 1000;
  return c.aud === moiTruong && c.exp > s && c.iat <= s + 30;
}

export type DongPhien = {
  id: string;
  device_id: string;
  chuoi: string | null;
  expires_at: number;
  revoked_at: number | null;
  thay_boi: string | null;
  xoay_luc: number | null;
};

export type QuyetDinhLamMoi =
  | { loai: 'xoay' }
  | { loai: 'khong-co' }
  | { loai: 'het-han' }
  | { loai: 'thu-hoi' }
  /** Token đã xoay được gửi lại trong ân hạn: từ chối nhẹ. */
  | { loai: 'an-han' }
  /** Dùng lại token đã xoay -> nghi bị đánh cắp: thu hồi CẢ chuỗi + sự kiện TOKEN_REUSE. */
  | { loai: 'dung-lai'; chuoi: string };

export function quyetDinhLamMoi(d: DongPhien | null, bayGio: number): QuyetDinhLamMoi {
  if (!d) return { loai: 'khong-co' };
  if (d.thay_boi !== null) {
    if (d.xoay_luc !== null && bayGio - d.xoay_luc <= AN_HAN_XOAY_MS) return { loai: 'an-han' };
    return { loai: 'dung-lai', chuoi: d.chuoi ?? d.id };
  }
  if (d.revoked_at !== null) return { loai: 'thu-hoi' };
  if (d.expires_at <= bayGio) return { loai: 'het-han' };
  return { loai: 'xoay' };
}

/** Lấy token từ header Authorization: Bearer. */
export function docBearer(h: string | null | undefined): string | null {
  const m = /^Bearer ([A-Za-z0-9_.-]{20,2048})$/.exec(h ?? '');
  return m ? (m[1] ?? null) : null;
}
