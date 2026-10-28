// Lớp bảo vệ nội dung web (SEC-WEB-SHIELD). Phase N0 chỉ định nghĩa cấu hình; hành vi thêm ở phase S9.
export type MucBaoVe = 'tat' | 'nhe' | 'chat';

export type CauHinhShield = {
  muc: MucBaoVe;
  /** Endpoint nhận tín hiệu, mặc định /v1/web/signals của Worker. */
  diemNhanTinHieu?: string;
};

const HOP_LE: readonly MucBaoVe[] = ['tat', 'nhe', 'chat'];

export function chuanHoaMuc(giaTri: unknown): MucBaoVe {
  return HOP_LE.includes(giaTri as MucBaoVe) ? (giaTri as MucBaoVe) : 'chat';
}
