// Chuỗi giao diện của lớp khiên (vi / en theo `<html lang>`). Gói nhúng vào cả landing (Astro) lẫn admin (React) nên giữ
// từ điển riêng, nhỏ; không nối chuỗi.
export type ChuoiKhien = { tieuDe: string; moTa: string };

const CHUOI: Readonly<Record<'vi' | 'en', ChuoiKhien>> = Object.freeze({
  vi: {
    tieuDe: 'Nội dung tạm ẩn',
    moTa: 'Trang phát hiện công cụ nhà phát triển đang mở. Hãy đóng công cụ để tiếp tục xem.',
  },
  en: {
    tieuDe: 'Content temporarily hidden',
    moTa: 'Developer tools appear to be open. Close them to continue.',
  },
});

export function chuoiTheoNgonNgu(lang: string | null | undefined): ChuoiKhien {
  return (lang ?? '').toLowerCase().startsWith('en') ? CHUOI.en : CHUOI.vi;
}
