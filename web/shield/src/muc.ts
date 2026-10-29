// Mức bảo vệ (SEC-WEB-SHIELD): `tat` tắt hẳn · `nhe` chỉ chặn phím tắt + kéo ảnh + in · `chat` thêm chặn chọn / sao chép /
// menu chuột phải và dò công cụ nhà phát triển. Mặc định và khi lỗi: `chat` (đóng khi lỗi).
export type MucBaoVe = 'tat' | 'nhe' | 'chat';

export type Trang = 'landing' | 'admin';

const HOP_LE: readonly MucBaoVe[] = ['tat', 'nhe', 'chat'];

export function chuanHoaMuc(giaTri: unknown): MucBaoVe {
  return HOP_LE.includes(giaTri as MucBaoVe) ? (giaTri as MucBaoVe) : 'chat';
}

export function chuanHoaTrang(giaTri: unknown): Trang {
  return giaTri === 'admin' ? 'admin' : 'landing';
}

export type HanhVi = {
  /** SH-02: phím tắt xem nguồn / lưu / in / công cụ nhà phát triển. */
  phimTat: boolean;
  /** SH-01: kéo-thả ảnh. */
  keoAnh: boolean;
  /** SH-02: `@media print` ẩn nội dung. */
  chanIn: boolean;
  /** SH-01: menu chuột phải. */
  menuChuot: boolean;
  /** SH-01: chọn / sao chép / cắt nội dung trình bày. */
  saoChep: boolean;
  /** SH-03: dò công cụ nhà phát triển. */
  doDevtools: boolean;
};

export function hanhViTheoMuc(muc: MucBaoVe): HanhVi {
  const nhe = muc !== 'tat';
  const chat = muc === 'chat';
  return { phimTat: nhe, keoAnh: nhe, chanIn: nhe, menuChuot: chat, saoChep: chat, doDevtools: chat };
}
