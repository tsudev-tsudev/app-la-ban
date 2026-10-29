// S3 (SEC-NET) - chữ ký request bằng khoá thiết bị (Spec §7.5). Chuỗi chuẩn:
//   METHOD \n PATH \n SORTED_QUERY \n SHA256_HEX(BODY) \n TIMESTAMP \n NONCE
// PHẢI khớp từng byte với packages/security_sdk/lib/src/domain/chuoi_ky.dart (test chéo bằng cùng vector).
// Phiên = Bearer JWT (cnf.jkt gắn đúng khoá này) nên không cần header X-Session riêng.
import { laNonceHopLe } from './nonce';

export const TIEU_DE_KY = { thietBi: 'x-device-id', ts: 'x-timestamp', nonce: 'x-nonce', chuKy: 'x-signature' } as const;
/** Nonce request sống 5 phút (Spec §7.5 mục 2) - dài hơn cửa sổ lệch giờ 2 x 60 s. */
export const NONCE_YEU_CAU_TTL_MS = 5 * 60 * 1000;
/** Thân request được ký tối đa (đọc vào bộ nhớ trước khi kiểm). */
export const THAN_KY_TOI_DA = 64 * 1024;

/** Mã hoá phần trăm RFC 3986: chỉ giữ A-Z a-z 0-9 - . _ ~ (encodeURIComponent còn để lọt ! ' ( ) *). */
export function maHoaRfc3986(s: string): string {
  return encodeURIComponent(s).replace(/[!'()*]/g, (k) => `%${k.charCodeAt(0).toString(16).toUpperCase()}`);
}

/**
 * Query (không có `?`) -> dạng chuẩn: giải mã từng cặp (`+` = khoảng trắng như form), sắp theo khoá rồi giá trị (so theo
 * đơn vị mã UTF-16 - Dart `compareTo` cùng thứ tự), mã hoá lại RFC 3986, nối `&`. Rỗng -> ''.
 */
export function querySapXep(query: string): string {
  const cap: [string, string][] = [];
  for (const [k, v] of new URLSearchParams(query)) cap.push([k, v]);
  cap.sort(([k1, v1], [k2, v2]) => (k1 < k2 ? -1 : k1 > k2 ? 1 : v1 < v2 ? -1 : v1 > v2 ? 1 : 0));
  return cap.map(([k, v]) => `${maHoaRfc3986(k)}=${maHoaRfc3986(v)}`).join('&');
}

export type PhanKyYeuCau = { phuongThuc: string; duongDan: string; query: string; bamThan: string; ts: number; nonce: string };

export function chuoiYeuCau(p: PhanKyYeuCau): string {
  return `${p.phuongThuc.toUpperCase()}\n${p.duongDan}\n${querySapXep(p.query)}\n${p.bamThan}\n${p.ts}\n${p.nonce}`;
}

export type TieuDeKy = { thietBi: string | null; ts: number; nonce: string; chuKy: string };

/** Đọc bộ header ký; thiếu / sai dạng -> null. `ts` = mili giây UTC. */
export function docTieuDeKy(lay: (ten: string) => string | undefined): TieuDeKy | null {
  const ts = lay(TIEU_DE_KY.ts) ?? '';
  const nonce = lay(TIEU_DE_KY.nonce);
  const chuKy = lay(TIEU_DE_KY.chuKy) ?? '';
  const thietBi = lay(TIEU_DE_KY.thietBi) ?? null;
  if (!/^\d{12,15}$/.test(ts) || !laNonceHopLe(nonce) || !/^[A-Za-z0-9_-]{80,100}$/.test(chuKy)) return null;
  if (thietBi !== null && !/^[0-9A-Z]{26}$/.test(thietBi)) return null;
  return { thietBi, ts: Number(ts), nonce, chuKy };
}

/** Lý do từ chối trước khi kiểm chữ ký (rẻ, không cần khoá). null = qua. */
export function kiemTruocKy(t: TieuDeKy, claimSub: string, bayGio: number, lechToiDaMs: number): 'thiet-bi-khac' | 'lech-gio' | null {
  if (t.thietBi !== null && t.thietBi !== claimSub) return 'thiet-bi-khac';
  if (Math.abs(bayGio - t.ts) > lechToiDaMs) return 'lech-gio';
  return null;
}
