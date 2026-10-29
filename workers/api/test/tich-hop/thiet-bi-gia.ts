// Thiết bị + Google giả cho test S2: khoá P-256 (như Android Keystore, chữ ký DER), khoá phiên server, service account
// RSA và bộ giả lập oauth2 / decodeIntegrityToken. Token Integrity giả = "gia." + base64url(JSON phán quyết).
import { b64urlTuByte, b64urlTuChuoi, byteTuB64url } from '../../src/thuan/ma-hoa';

const EC = { name: 'ECDSA', namedCurve: 'P-256' } as const;

/** 64 byte r||s -> DER (như `Signature.getInstance("SHA256withECDSA")` trên Android). */
export function thoSangDer(tho: Uint8Array): Uint8Array {
  const so = (b: Uint8Array) => {
    let i = 0;
    while (i < b.length - 1 && b[i] === 0) i++;
    const t = b.subarray(i);
    return (t[0] ?? 0) & 0x80 ? Uint8Array.of(0, ...t) : t;
  };
  const r = so(tho.subarray(0, 32));
  const s = so(tho.subarray(32));
  return Uint8Array.of(0x30, r.length + s.length + 4, 0x02, r.length, ...r, 0x02, s.length, ...s);
}

export type ThietBiGia = { khoaCongKhai: string; ky: (chuoi: string) => Promise<string> };

export async function taoThietBiGia(): Promise<ThietBiGia> {
  const cap = (await crypto.subtle.generateKey(EC, true, ['sign', 'verify'])) as CryptoKeyPair;
  const spki = (await crypto.subtle.exportKey('spki', cap.publicKey)) as ArrayBuffer;
  return {
    khoaCongKhai: b64urlTuByte(spki),
    ky: async (chuoi) =>
      b64urlTuByte(thoSangDer(new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, cap.privateKey, new TextEncoder().encode(chuoi))))),
  };
}

export async function taoKhoaPhien(kid = 'k1'): Promise<string> {
  const cap = (await crypto.subtle.generateKey(EC, true, ['sign', 'verify'])) as CryptoKeyPair;
  return JSON.stringify({ ...((await crypto.subtle.exportKey('jwk', cap.privateKey)) as JsonWebKey), kid });
}

export async function taoServiceAccount(): Promise<string> {
  const cap = (await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: Uint8Array.of(1, 0, 1), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  )) as CryptoKeyPair;
  const der = new Uint8Array((await crypto.subtle.exportKey('pkcs8', cap.privateKey)) as ArrayBuffer);
  let s = '';
  for (const b of der) s += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(s).replace(/.{64}/g, '$&\n')}\n-----END PRIVATE KEY-----\n`;
  return JSON.stringify({ type: 'service_account', client_email: 'la-ban-integrity@thu.iam.gserviceaccount.com', private_key: pem, private_key_id: 'abc' });
}

export const tokenGia = (phanQuyet: unknown) => `gia.${b64urlTuChuoi(JSON.stringify(phanQuyet))}`;

/** Trạng thái giả lập Google: đếm lượt gọi, ép lỗi dịch vụ. */
export const google = { loi: 0 as number, goiOauth: 0, goiGiaiMa: 0 };

export async function googleGia(req: Request): Promise<Response> {
  const url = new URL(req.url);
  if (url.host === 'oauth2.googleapis.com') {
    google.goiOauth++;
    const body = await req.text();
    if (!body.includes('assertion=')) return new Response('{}', { status: 400 });
    return Response.json({ access_token: 'at-thu', expires_in: 3600 });
  }
  if (url.host === 'playintegrity.googleapis.com') {
    google.goiGiaiMa++;
    if (google.loi === 4002) return Response.json({ error: { code: 400, message: 'The cloud project is not linked.', status: 'INVALID_ARGUMENT' } }, { status: 400 });
    if (google.loi === 4001) return Response.json({ error: { code: 400, message: 'App is not found.', status: 'INVALID_ARGUMENT' } }, { status: 400 });
    if (google.loi) return new Response('{}', { status: google.loi });
    if (req.headers.get('authorization') !== 'Bearer at-thu') return new Response('{}', { status: 401 });
    const { integrity_token: t } = (await req.json()) as { integrity_token: string };
    const b = t.startsWith('gia.') ? byteTuB64url(t.slice(4)) : null;
    if (!b) return Response.json({ error: { code: 400 } }, { status: 400 });
    return Response.json({ tokenPayloadExternal: JSON.parse(new TextDecoder().decode(b)) });
  }
  return new Response('khong-ho-tro', { status: 599 });
}
