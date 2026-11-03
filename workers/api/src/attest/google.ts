// Giải mã token Play Integrity qua Google (decodeIntegrityToken) bằng service account PLAY_INTEGRITY_SA_JSON
// (wrangler secret, dự án Cloud số PI_SO_DU_AN). Lỗi mạng / Google / thiếu cấu hình -> LoiDichVu -> mức 'unverified'
// (ID-05), không bao giờ coi là đạt.
import type { Env } from '../moi-truong';
import { b64urlTuByte, b64urlTuChuoi } from '../thuan/ma-hoa';
import { claimGoogle, PHAM_VI_INTEGRITY, pemSangDer, schemaPhanQuyet, schemaServiceAccount, type PhanQuyet } from '../thuan/play-integrity';

export class LoiDichVu extends Error {
  constructor(readonly lyDo: string) {
    super(lyDo);
    this.name = 'LoiDichVu';
  }
}

const HET_GIO_MS = 5000;
const demToken = new Map<string, { email: string; token: string; het: number }>();

/** Access token OAuth của service account cho phạm vi [phamVi] (đệm theo isolate tới ~1 phút trước khi hết hạn). */
export async function layAccessToken(saJson: string, bayGio: number, phamVi: string = PHAM_VI_INTEGRITY): Promise<string> {
  let sa;
  try {
    sa = schemaServiceAccount.parse(JSON.parse(saJson));
  } catch {
    throw new LoiDichVu('sa-sai-dang');
  }
  const dem = demToken.get(phamVi);
  if (dem && dem.email === sa.client_email && dem.het > bayGio + 60_000) return dem.token;
  const khoa = await crypto.subtle.importKey('pkcs8', pemSangDer(sa.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const header = b64urlTuChuoi(JSON.stringify({ alg: 'RS256', typ: 'JWT', ...(sa.private_key_id ? { kid: sa.private_key_id } : {}) }));
  const dau = `${header}.${b64urlTuChuoi(JSON.stringify(claimGoogle(sa.client_email, bayGio, phamVi)))}`;
  const chuKy = b64urlTuByte(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', khoa, new TextEncoder().encode(dau)));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${dau}.${chuKy}`,
    signal: AbortSignal.timeout(HET_GIO_MS),
  });
  if (!res.ok) throw new LoiDichVu(`oauth-${res.status}`);
  const du = (await res.json()) as { access_token?: unknown; expires_in?: unknown };
  if (typeof du.access_token !== 'string') throw new LoiDichVu('oauth-thieu-token');
  const songGiay = typeof du.expires_in === 'number' ? du.expires_in : 3600;
  demToken.set(phamVi, { email: sa.client_email, token: du.access_token, het: bayGio + songGiay * 1000 });
  return du.access_token;
}

/** Giải mã token của gói [goi]. 4xx từ Google (token hỏng / giả / sai dự án) -> null; lỗi dịch vụ -> LoiDichVu. */
export async function giaiMaToken(env: Env, goi: string, token: string, bayGio = Date.now()): Promise<PhanQuyet | null> {
  if (!env.PLAY_INTEGRITY_SA_JSON) throw new LoiDichVu('chua-cau-hinh');
  let res: Response;
  try {
    const at = await layAccessToken(env.PLAY_INTEGRITY_SA_JSON, bayGio);
    res = await fetch(`https://playintegrity.googleapis.com/v1/${encodeURIComponent(goi)}:decodeIntegrityToken`, {
      method: 'POST',
      headers: { authorization: `Bearer ${at}`, 'content-type': 'application/json' },
      body: JSON.stringify({ integrity_token: token }),
      signal: AbortSignal.timeout(HET_GIO_MS),
    });
  } catch (e) {
    if (e instanceof LoiDichVu) throw e;
    throw new LoiDichVu('mang');
  }
  if (res.status === 401 || res.status === 403) {
    demToken.delete(PHAM_VI_INTEGRITY);
    throw new LoiDichVu(`google-${res.status}`);
  }
  if (res.status >= 500 || res.status === 429) throw new LoiDichVu(`google-${res.status}`);
  if (!res.ok) {
    // Dự án Cloud chưa được phép / chưa liên kết: lỗi CẤU HÌNH phía mình -> unverified. "App is not found" thì KHÔNG phải:
    // máy thật (30/10, app chưa lên Play) giải mã bình thường; câu đó chỉ gặp với token rác / giả -> failed (QUYET_DINH Q35).
    const vb = await res.text().catch(() => '');
    if (/not linked|cloud project/i.test(vb)) throw new LoiDichVu('du-an-chua-lien-ket');
    return null;
  }
  const du = (await res.json().catch(() => null)) as { tokenPayloadExternal?: unknown } | null;
  const kq = schemaPhanQuyet.safeParse(du?.tokenPayloadExternal);
  return kq.success ? kq.data : null;
}

/** Quên access token đã đệm của phạm vi (Google trả 401 / 403 - token bị thu hồi / quyền đổi). */
export function quenAccessToken(phamVi: string): void {
  demToken.delete(phamVi);
}
