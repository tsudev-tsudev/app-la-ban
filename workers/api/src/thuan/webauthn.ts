// Passkey WebAuthn Level 2 cho Admin SOC (S6, SEC-ADM - MFA bắt buộc, Spec §8.1). Không SDK ngoài: tự kiểm clientDataJSON,
// authenticatorData, khoá COSE và chữ ký bằng WebCrypto. Attestation 'none' (không cần biết hãng authenticator) nên không
// kiểm attStmt; bắt buộc User Present + User Verified (sinh trắc / PIN trên thiết bị).
import { giaiMaCbor, LoiCbor, type GiaTriCbor } from './cbor';
import { b64urlTuByte, byteTuB64url, derSangTho } from './ma-hoa';

/** ES256, EdDSA (Ed25519), RS256 - đủ cho Android / iOS / Windows Hello / khoá bảo mật. */
export const THUAT_TOAN = [-7, -8, -257] as const;
export type ThuatToan = (typeof THUAT_TOAN)[number];

export const THACH_THUC_HAN_MS = 5 * 60_000;

export type KhoaCongKhai = { alg: ThuatToan; jwk: JsonWebKey };

export type LoiWebAuthn =
  | 'client-data-loi'
  | 'sai-loai'
  | 'sai-thach-thuc'
  | 'sai-nguon'
  | 'sai-rp'
  | 'thieu-up'
  | 'thieu-uv'
  | 'auth-data-loi'
  | 'khoa-loi'
  | 'thuat-toan'
  | 'chu-ky'
  | 'dem-lui';

export class LoiXacMinh extends Error {
  constructor(readonly ma: LoiWebAuthn) {
    super(ma);
  }
}

const CO_UP = 0x01;
const CO_UV = 0x04;
const CO_AT = 0x40;

export type AuthData = {
  rpIdHash: Uint8Array;
  flags: number;
  signCount: number;
  credentialId?: Uint8Array;
  khoaCose?: Map<GiaTriCbor, GiaTriCbor>;
};

export function phanTichAuthData(b: Uint8Array): AuthData {
  if (b.length < 37) throw new LoiXacMinh('auth-data-loi');
  const flags = b[32] as number;
  const signCount = ((b[33] as number) * 2 ** 24) + (((b[34] as number) << 16) | ((b[35] as number) << 8) | (b[36] as number));
  const kq: AuthData = { rpIdHash: b.slice(0, 32), flags, signCount };
  if (flags & CO_AT) {
    if (b.length < 55) throw new LoiXacMinh('auth-data-loi');
    const dai = ((b[53] as number) << 8) | (b[54] as number);
    if (dai < 16 || dai > 1023 || 55 + dai > b.length) throw new LoiXacMinh('auth-data-loi');
    kq.credentialId = b.slice(55, 55 + dai);
    try {
      const { giaTri } = giaiMaCbor(b, 55 + dai);
      if (!(giaTri instanceof Map)) throw new LoiXacMinh('khoa-loi');
      kq.khoaCose = giaTri;
    } catch (e) {
      if (e instanceof LoiCbor) throw new LoiXacMinh('khoa-loi');
      throw e;
    }
  }
  return kq;
}

/** Khoá COSE (RFC 9053) -> JWK cho WebCrypto. Chỉ nhận đúng cặp kty / alg / crv đã khai báo. */
export function coseSangJwk(m: Map<GiaTriCbor, GiaTriCbor>): KhoaCongKhai {
  const kty = m.get(1);
  const alg = m.get(3);
  const byte = (k: number): string => {
    const v = m.get(k);
    if (!(v instanceof Uint8Array) || v.length === 0) throw new LoiXacMinh('khoa-loi');
    return b64urlTuByte(v);
  };
  if (alg === -7 && kty === 2 && m.get(-1) === 1) {
    return { alg, jwk: { kty: 'EC', crv: 'P-256', x: byte(-2), y: byte(-3) } };
  }
  if (alg === -8 && kty === 1 && m.get(-1) === 6) {
    return { alg, jwk: { kty: 'OKP', crv: 'Ed25519', x: byte(-2) } };
  }
  if (alg === -257 && kty === 3) {
    return { alg, jwk: { kty: 'RSA', n: byte(-1), e: byte(-2) } };
  }
  throw new LoiXacMinh('thuat-toan');
}

type ClientData = { type: string; challenge: string; origin: string; crossOrigin?: boolean };

/** Kiểm clientDataJSON: đúng loại, đúng thách thức đã cấp, origin nằm trong danh sách SOC, không nhúng chéo nguồn. */
export function kiemClientData(byte: Uint8Array, loai: 'webauthn.create' | 'webauthn.get', thachThuc: string, nguon: readonly string[]): ClientData {
  let cd: ClientData;
  try {
    cd = JSON.parse(new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(byte)) as ClientData;
  } catch {
    throw new LoiXacMinh('client-data-loi');
  }
  if (typeof cd !== 'object' || cd === null || typeof cd.type !== 'string') throw new LoiXacMinh('client-data-loi');
  if (cd.type !== loai) throw new LoiXacMinh('sai-loai');
  if (cd.challenge !== thachThuc) throw new LoiXacMinh('sai-thach-thuc');
  if (!nguon.includes(cd.origin) || cd.crossOrigin === true) throw new LoiXacMinh('sai-nguon');
  return cd;
}

async function kiemRpVaCo(ad: AuthData, rpId: string): Promise<void> {
  const bam = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(rpId)));
  if (bam.length !== ad.rpIdHash.length || bam.some((x, i) => x !== ad.rpIdHash[i])) throw new LoiXacMinh('sai-rp');
  if (!(ad.flags & CO_UP)) throw new LoiXacMinh('thieu-up');
  if (!(ad.flags & CO_UV)) throw new LoiXacMinh('thieu-uv');
}

export type DauVaoDangKy = { clientDataJSON: string; attestationObject: string };
export type KetQuaDangKy = { credentialId: string; khoa: KhoaCongKhai; signCount: number };

/** Kiểm phản hồi navigator.credentials.create(). */
export async function kiemDangKy(v: DauVaoDangKy, thachThuc: string, rpId: string, nguon: readonly string[]): Promise<KetQuaDangKy> {
  const cdByte = byteTuB64url(v.clientDataJSON);
  const attByte = byteTuB64url(v.attestationObject);
  if (!cdByte || !attByte) throw new LoiXacMinh('client-data-loi');
  kiemClientData(cdByte, 'webauthn.create', thachThuc, nguon);
  let att: GiaTriCbor;
  try {
    att = giaiMaCbor(attByte).giaTri;
  } catch {
    throw new LoiXacMinh('auth-data-loi');
  }
  const authData = att instanceof Map ? att.get('authData') : undefined;
  if (!(authData instanceof Uint8Array)) throw new LoiXacMinh('auth-data-loi');
  const ad = phanTichAuthData(authData);
  await kiemRpVaCo(ad, rpId);
  if (!ad.credentialId || !ad.khoaCose) throw new LoiXacMinh('auth-data-loi');
  const khoa = coseSangJwk(ad.khoaCose);
  await nhapKhoa(khoa);
  return { credentialId: b64urlTuByte(ad.credentialId), khoa, signCount: ad.signCount };
}

export type DauVaoXacThuc = { clientDataJSON: string; authenticatorData: string; signature: string };

/**
 * Kiểm phản hồi navigator.credentials.get() với khoá đã lưu. Bộ đếm: nếu authenticator có đếm (khác 0) thì phải tăng -
 * tụt / đứng yên = dấu hiệu sao chép khoá. Passkey đồng bộ (Google / iCloud) luôn trả 0 nên không kiểm.
 */
export async function kiemXacThuc(
  v: DauVaoXacThuc,
  khoa: KhoaCongKhai,
  demCu: number,
  thachThuc: string,
  rpId: string,
  nguon: readonly string[],
): Promise<{ signCount: number }> {
  const cdByte = byteTuB64url(v.clientDataJSON);
  const adByte = byteTuB64url(v.authenticatorData);
  const chuKy = byteTuB64url(v.signature);
  if (!cdByte || !adByte || !chuKy) throw new LoiXacMinh('client-data-loi');
  kiemClientData(cdByte, 'webauthn.get', thachThuc, nguon);
  const ad = phanTichAuthData(adByte);
  await kiemRpVaCo(ad, rpId);
  if ((ad.signCount !== 0 || demCu !== 0) && ad.signCount <= demCu) throw new LoiXacMinh('dem-lui');
  const bamCd = new Uint8Array(await crypto.subtle.digest('SHA-256', cdByte));
  const duLieu = new Uint8Array(adByte.length + bamCd.length);
  duLieu.set(adByte);
  duLieu.set(bamCd, adByte.length);
  const k = await nhapKhoa(khoa);
  let ok: boolean;
  if (khoa.alg === -7) {
    const tho = derSangTho(chuKy);
    if (!tho) throw new LoiXacMinh('chu-ky');
    ok = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, k, tho, duLieu);
  } else if (khoa.alg === -8) {
    ok = await crypto.subtle.verify({ name: 'Ed25519' }, k, chuKy, duLieu);
  } else {
    ok = await crypto.subtle.verify({ name: 'RSASSA-PKCS1-v1_5' }, k, chuKy, duLieu);
  }
  if (!ok) throw new LoiXacMinh('chu-ky');
  return { signCount: ad.signCount };
}

async function nhapKhoa(k: KhoaCongKhai): Promise<CryptoKey> {
  const thuatToan =
    k.alg === -7
      ? { name: 'ECDSA', namedCurve: 'P-256' }
      : k.alg === -8
        ? { name: 'Ed25519' }
        : { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' };
  try {
    return await crypto.subtle.importKey('jwk', k.jwk, thuatToan, false, ['verify']);
  } catch {
    throw new LoiXacMinh('khoa-loi');
  }
}

/** rpId = hostname của origin SOC đang dùng; origin phải nằm trong danh sách cấu hình. */
export function rpIdTuNguon(origin: string | null | undefined, nguon: readonly string[]): string | null {
  if (!origin || !nguon.includes(origin)) return null;
  try {
    return new URL(origin).hostname;
  } catch {
    return null;
  }
}

/** Tuỳ chọn cho navigator.credentials.create() (JSON - client đổi base64url sang ArrayBuffer). */
export function tuyChonDangKy(p: { thachThuc: string; rpId: string; email: string; userId: string; loaiTru: string[] }) {
  return {
    challenge: p.thachThuc,
    rp: { id: p.rpId, name: 'La bàn SOC' },
    user: { id: p.userId, name: p.email, displayName: p.email },
    pubKeyCredParams: THUAT_TOAN.map((alg) => ({ type: 'public-key' as const, alg })),
    timeout: THACH_THUC_HAN_MS,
    attestation: 'none' as const,
    authenticatorSelection: { residentKey: 'preferred' as const, userVerification: 'required' as const },
    excludeCredentials: p.loaiTru.map((id) => ({ type: 'public-key' as const, id })),
  };
}

export function tuyChonXacThuc(p: { thachThuc: string; rpId: string; choPhep: string[] }) {
  return {
    challenge: p.thachThuc,
    rpId: p.rpId,
    timeout: THACH_THUC_HAN_MS,
    userVerification: 'required' as const,
    allowCredentials: p.choPhep.map((id) => ({ type: 'public-key' as const, id })),
  };
}
