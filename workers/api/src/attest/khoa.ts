// WebCrypto cho S2: khoá ký phiên của server (ES256, wrangler secret KHOA_PHIEN) và khoá công khai thiết bị (P-256 SPKI).
import { b64urlTuByte, byteTuB64url, derSangTho } from '../thuan/ma-hoa';
import { phanKy, tachJwt, claimConHan, type ClaimPhien } from '../thuan/phien';

const EC = { name: 'ECDSA', namedCurve: 'P-256' } as const;
const KY = { name: 'ECDSA', hash: 'SHA-256' } as const;

export type KhoaPhien = { kid: string; ky: CryptoKey; kiem: ReadonlyMap<string, CryptoKey> };

type JwkRieng = { kty: 'EC'; crv: 'P-256'; x: string; y: string; d: string; kid: string };

function laJwkRieng(j: Record<string, unknown>): j is JwkRieng {
  return (
    j.kty === 'EC' &&
    j.crv === 'P-256' &&
    [j.x, j.y, j.d].every((v) => typeof v === 'string' && /^[A-Za-z0-9_-]{43}$/.test(v)) &&
    typeof j.kid === 'string' &&
    /^[A-Za-z0-9_-]{1,32}$/.test(j.kid)
  );
}

let dem: { nguon: string; khoa: Promise<KhoaPhien> } | null = null;

/**
 * KHOA_PHIEN = JSON một JWK riêng tư EC P-256 có `kid`, hoặc mảng JWK (phần tử đầu ký, mọi phần tử đều kiểm - để xoay
 * khoá không làm rơi phiên đang sống). Đệm theo isolate.
 */
export function napKhoaPhien(biMat: string): Promise<KhoaPhien> {
  if (dem?.nguon === biMat) return dem.khoa;
  const khoa = (async () => {
    const goc = JSON.parse(biMat) as unknown;
    const ds = (Array.isArray(goc) ? goc : [goc]) as Record<string, unknown>[];
    if (!ds.length || !ds.every(laJwkRieng)) throw new Error('KHOA_PHIEN sai dạng');
    const kiem = new Map<string, CryptoKey>();
    for (const j of ds) {
      const congKhai: JsonWebKey = { kty: 'EC', crv: 'P-256', x: j.x, y: j.y, ext: true };
      kiem.set(j.kid, await crypto.subtle.importKey('jwk', congKhai, EC, false, ['verify']));
    }
    const dau = ds[0] as JwkRieng;
    const rieng: JsonWebKey = { kty: 'EC', crv: 'P-256', x: dau.x, y: dau.y, d: dau.d };
    return { kid: dau.kid, ky: await crypto.subtle.importKey('jwk', rieng, EC, false, ['sign']), kiem };
  })();
  dem = { nguon: biMat, khoa };
  khoa.catch(() => {
    if (dem?.khoa === khoa) dem = null;
  });
  return khoa;
}

export async function kyJwt(k: KhoaPhien, claim: ClaimPhien): Promise<string> {
  const dau = phanKy(k.kid, claim);
  const chuKy = await crypto.subtle.sign(KY, k.ky, new TextEncoder().encode(dau));
  return `${dau}.${b64urlTuByte(chuKy)}`;
}

/** JWT hợp lệ (chữ ký + hạn + môi trường) -> claim; còn lại null. */
export async function kiemJwt(k: KhoaPhien, jwt: string, moiTruong: string, bayGio: number): Promise<ClaimPhien | null> {
  const t = tachJwt(jwt);
  if (!t) return null;
  const khoa = k.kiem.get(t.kid);
  if (!khoa) return null;
  const dung = await crypto.subtle.verify(KY, khoa, t.chuKy, new TextEncoder().encode(t.phanKy));
  return dung && claimConHan(t.claim, moiTruong, bayGio) ? t.claim : null;
}

export type KhoaThietBi = { khoa: CryptoKey; jkt: string };

/** Khoá công khai thiết bị (SPKI DER base64url, P-256) + thumbprint RFC 7638. Sai dạng / đường cong khác -> null. */
export async function nhapKhoaThietBi(spkiB64url: string): Promise<KhoaThietBi | null> {
  const der = byteTuB64url(spkiB64url);
  if (!der || der.length < 80 || der.length > 100) return null;
  try {
    const khoa = await crypto.subtle.importKey('spki', der, EC, true, ['verify']);
    const jwk = (await crypto.subtle.exportKey('jwk', khoa)) as JsonWebKey;
    const chuan = JSON.stringify({ crv: jwk.crv, kty: jwk.kty, x: jwk.x, y: jwk.y });
    const jkt = b64urlTuByte(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(chuan)));
    return { khoa, jkt };
  } catch {
    return null;
  }
}

/** Kiểm chữ ký thiết bị (DER base64url, như Android Keystore trả) trên [chuoi]. */
export async function kiemChuKyThietBi(k: CryptoKey, chuoi: string, chuKyB64url: string): Promise<boolean> {
  const der = byteTuB64url(chuKyB64url);
  const tho = der ? derSangTho(der) : null;
  if (!tho) return false;
  return crypto.subtle.verify(KY, k, tho, new TextEncoder().encode(chuoi));
}

export async function sha256B64url(s: string): Promise<string> {
  return b64urlTuByte(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)));
}

/** Chuỗi ngẫu nhiên [n] byte dạng base64url (thách thức, refresh token). */
export function ngauNhienB64url(n = 32): string {
  return b64urlTuByte(crypto.getRandomValues(new Uint8Array(n)));
}
