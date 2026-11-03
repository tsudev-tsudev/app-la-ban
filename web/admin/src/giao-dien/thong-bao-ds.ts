// Danh sách toast thuần (A9c chống nhấp nháy): cùng nội dung + loại đang hiện thì KHÔNG chồng thêm cái mới - thay bằng
// id mới ở đúng vị trí cũ (đặt lại hạn ẩn), để lỗi lặp (vd làm mới nền định kỳ thất bại) không làm cột toast nhảy.
export type LoaiThongBao = 'ok' | 'loi' | 'tin';
export type MotThongBao = { id: number; loai: LoaiThongBao; noiDung: string };

export const TOI_DA_THONG_BAO = 4;

export function themThongBao(ds: readonly MotThongBao[], moi: MotThongBao): MotThongBao[] {
  const i = ds.findIndex((x) => x.loai === moi.loai && x.noiDung === moi.noiDung);
  if (i >= 0) return ds.map((x, j) => (j === i ? moi : x));
  return [...ds.slice(-(TOI_DA_THONG_BAO - 1)), moi];
}
