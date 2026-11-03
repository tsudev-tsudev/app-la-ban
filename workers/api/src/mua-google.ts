// Gọi Google Play Developer API (M1a bước 3, Q55) bằng service account sẵn có (PLAY_INTEGRITY_SA_JSON, phạm vi
// androidpublisher - người dùng cấp quyền "Xem dữ liệu tài chính / quản lý đơn hàng" trong Play Console).
// 404 / 410 / 400 = token không tồn tại / không thuộc gói -> null; lỗi mạng / 401 / 403 / 429 / 5xx -> LoiDichVu.
import { LoiDichVu, layAccessToken, quenAccessToken } from './attest/google';
import type { Env } from './moi-truong';
import { PHAM_VI_PUBLISHER } from './thuan/play-integrity';
import { schemaGoiDangKy, schemaMuaMotLan, type GoiDangKy, type MuaMotLan } from './thuan/quyen-loi';

const GOC = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const HET_GIO_MS = 6000;

async function goiGoogle(env: Env, duong: string, phuongThuc: 'GET' | 'POST' = 'GET', than?: unknown): Promise<unknown> {
  if (!env.PLAY_INTEGRITY_SA_JSON) throw new LoiDichVu('chua-cau-hinh');
  let res: Response;
  try {
    const at = await layAccessToken(env.PLAY_INTEGRITY_SA_JSON, Date.now(), PHAM_VI_PUBLISHER);
    res = await fetch(`${GOC}/${duong}`, {
      method: phuongThuc,
      headers: { authorization: `Bearer ${at}`, ...(than === undefined ? {} : { 'content-type': 'application/json' }) },
      ...(than === undefined ? {} : { body: JSON.stringify(than) }),
      signal: AbortSignal.timeout(HET_GIO_MS),
    });
  } catch (e) {
    if (e instanceof LoiDichVu) throw e;
    throw new LoiDichVu('mang');
  }
  if (res.status === 401 || res.status === 403) {
    quenAccessToken(PHAM_VI_PUBLISHER);
    throw new LoiDichVu(`google-${res.status}`);
  }
  if (res.status === 404 || res.status === 410 || res.status === 400) return null;
  if (!res.ok) throw new LoiDichVu(`google-${res.status}`);
  const vb = await res.text();
  return vb ? (JSON.parse(vb) as unknown) : {};
}

const ma = encodeURIComponent;

export async function layGoiDangKy(env: Env, goi: string, token: string): Promise<GoiDangKy | null> {
  const du = await goiGoogle(env, `${ma(goi)}/purchases/subscriptionsv2/tokens/${ma(token)}`);
  if (du === null) return null;
  const kq = schemaGoiDangKy.safeParse(du);
  if (!kq.success) throw new LoiDichVu('google-dang');
  return kq.data;
}

export async function layMuaMotLan(env: Env, goi: string, sanPham: string, token: string): Promise<MuaMotLan | null> {
  const du = await goiGoogle(env, `${ma(goi)}/purchases/products/${ma(sanPham)}/tokens/${ma(token)}`);
  if (du === null) return null;
  const kq = schemaMuaMotLan.safeParse(du);
  if (!kq.success) throw new LoiDichVu('google-dang');
  return kq.data;
}

/** Xác nhận (acknowledge) giao dịch - Play tự hoàn tiền nếu không xác nhận trong 3 ngày. */
export async function xacNhanMua(env: Env, goi: string, loai: 'sub' | 'inapp', sanPham: string, token: string): Promise<boolean> {
  const nhanh = loai === 'sub' ? 'subscriptions' : 'products';
  const du = await goiGoogle(env, `${ma(goi)}/purchases/${nhanh}/${ma(sanPham)}/tokens/${ma(token)}:acknowledge`, 'POST', {});
  return du !== null;
}

/** Voided Purchases (hoàn tiền / chargeback / huỷ) từ [tuMs] - cả gói đăng ký (type=1). Trả purchase token. */
export async function dsMuaBiHuy(env: Env, goi: string, tuMs: number, toiDaTrang = 5): Promise<string[]> {
  const ds: string[] = [];
  let trang: string | undefined;
  for (let i = 0; i < toiDaTrang; i++) {
    const q = new URLSearchParams({ startTime: String(tuMs), type: '1', maxResults: '1000' });
    if (trang) q.set('token', trang);
    const du = (await goiGoogle(env, `${ma(goi)}/purchases/voidedpurchases?${q}`)) as {
      voidedPurchases?: { purchaseToken?: unknown }[];
      tokenPagination?: { nextPageToken?: unknown };
    } | null;
    if (!du) break;
    for (const v of du.voidedPurchases ?? []) if (typeof v.purchaseToken === 'string') ds.push(v.purchaseToken);
    const tiep = du.tokenPagination?.nextPageToken;
    if (typeof tiep !== 'string' || !tiep) break;
    trang = tiep;
  }
  return ds;
}
