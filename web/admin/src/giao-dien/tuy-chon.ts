// Tuỳ chọn hiển thị của người xem (chỉ trong trình duyệt này): giao diện, ngôn ngữ, mật độ, độ đậm thuỷ vân, che khi rời.
// localStorage có thể bị chặn (chế độ riêng tư) -> mất tuỳ chọn, giao diện vẫn chạy với mặc định.
import { laMucThuyVan, type MucThuyVan } from '../khien/dau-vet';

export type MatDo = 'thoang' | 'gon';
export type TuyChon = { chuDe: 'light' | 'dark' | null; matDo: MatDo; thuyVan: MucThuyVan; cheKhiRoi: boolean };

const KHOA = 'soc-tuy-chon';
export const MAC_DINH: TuyChon = { chuDe: null, matDo: 'thoang', thuyVan: 'nhe', cheKhiRoi: false };

/** Chuỗi JSON đã lưu -> tuỳ chọn hợp lệ; trường hỏng / lạ lấy mặc định (không tin dữ liệu trong kho). */
export function docTuyChon(json: string | null, chuDeCu: string | null = null): TuyChon {
  let x: Record<string, unknown> = {};
  try {
    const v: unknown = json ? JSON.parse(json) : {};
    if (v && typeof v === 'object') x = v as Record<string, unknown>;
  } catch {
    x = {};
  }
  const chuDe = x.chuDe ?? chuDeCu;
  return {
    chuDe: chuDe === 'light' || chuDe === 'dark' ? chuDe : null,
    matDo: x.matDo === 'gon' ? 'gon' : 'thoang',
    thuyVan: laMucThuyVan(x.thuyVan) ? x.thuyVan : MAC_DINH.thuyVan,
    cheKhiRoi: x.cheKhiRoi === true,
  };
}

export function docKho(k: string): string | null {
  try {
    return localStorage.getItem(k);
  } catch {
    return null;
  }
}

export function ghiKho(k: string, v: string): void {
  try {
    localStorage.setItem(k, v);
  } catch {
    // Trình duyệt chặn lưu trữ - chỉ mất tuỳ chọn hiển thị.
  }
}

export function napTuyChon(): TuyChon {
  return docTuyChon(docKho(KHOA), docKho('soc-chu-de'));
}

export function luuTuyChon(t: TuyChon): void {
  ghiKho(KHOA, JSON.stringify(t));
}
