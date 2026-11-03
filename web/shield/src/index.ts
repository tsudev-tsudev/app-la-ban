// Lớp bảo vệ nội dung web (SEC-WEB-SHIELD, phase S9). Lớp răn đe + thu tín hiệu; lớp bảo vệ chính là SH-07 (Worker không
// gửi dữ liệu nhạy cảm xuống client khi chưa đủ quyền).
export { chuanHoaMuc, chuanHoaTrang, hanhViTheoMuc, type HanhVi, type MucBaoVe, type Trang } from './muc';
export { phanLoaiPhim, type LoaiPhim, type PhimNhan } from './phim';
export { capNhatDo, debuggerDangGan, ketLuan, kichThuocBatThuong, laTuDongHoa, NGUONG, TRANG_THAI_DAU, type DoKichThuoc, type TrangThaiDo } from './devtools';
export { giaiB64url, kiemGoi, maB64url, mucChoTrang, phanTichGoi, phanTichNoiDung, type GoiCauHinh, type NoiDungCauHinh } from './cau-hinh';
export { noiDungWatermark, soO } from './watermark';
export { chuoiTheoNgonNgu } from './ngon-ngu';

