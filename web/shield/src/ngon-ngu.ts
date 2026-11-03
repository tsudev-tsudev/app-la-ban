// Chuỗi giao diện của lớp khiên (vi / en theo `<html lang>`). Gói nhúng vào cả landing (Astro) lẫn admin (React) nên giữ
// từ điển riêng, nhỏ; không nối chuỗi.
export type ChuoiKhien = { tieuDe: string; moTa: string };

const CHUOI: Readonly<Record<'vi' | 'en', ChuoiKhien>> = Object.freeze({
  vi: {
    tieuDe: 'Đã tạm dừng hiển thị',
    moTa: 'Trang phát hiện công cụ nhà phát triển, gỡ lỗi từ xa hoặc phần mềm điều khiển trình duyệt. Hãy đóng các công cụ này (và tắt gỡ lỗi USB / không dây trên điện thoại) để tiếp tục.',
  },
  en: {
    tieuDe: 'Display paused',
    moTa: 'Developer tools, remote debugging or browser automation was detected. Close these tools (and turn off USB / wireless debugging on your phone) to continue.',
  },
});

export function chuoiTheoNgonNgu(lang: string | null | undefined): ChuoiKhien {
  return (lang ?? '').toLowerCase().startsWith('en') ? CHUOI.en : CHUOI.vi;
}
