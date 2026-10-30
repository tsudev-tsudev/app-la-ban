/// Định danh định dạng tệp xuất (để công cụ khác nhận ra, không đổi).
const dinhDangXuat = 'la-ban-du-lieu-ca-nhan';

/// Tăng khi đổi cấu trúc tệp xuất.
const phienBanDinhDangXuat = 1;

/// Hộp thư nhận yêu cầu về dữ liệu cá nhân (trùng Chính sách quyền riêng tư).
const thuRiengTu = 'privacy@tsudev.com';

/// Gói toàn bộ dữ liệu cá nhân app giữ trên máy thành một đối tượng JSON
/// (quyền truy cập + mang dữ liệu đi, NĐ 13/2023 Điều 9). Chỉ gồm dữ liệu
/// người dùng tạo / chọn - không khoá, không token phiên.
Map<String, Object?> goiDuLieuXuat({
  required String phienBanApp,
  required DateTime luc,
  required Map<String, Object?> caiDat,
  required Map<String, Object?> tuyChonLaBan,
  required Map<String, Object?> viTri,
  required List<Map<String, Object?>> diem,
  String? maThietBi,
}) => {
  'dinhDang': dinhDangXuat,
  'phienBanDinhDang': phienBanDinhDangXuat,
  'taoLuc': luc.toUtc().toIso8601String(),
  'phienBanApp': phienBanApp,
  'maThietBi': ?maThietBi,
  'caiDat': caiDat,
  'tuyChonLaBan': tuyChonLaBan,
  'viTri': viTri,
  'diem': diem,
};

/// Tên tệp gợi ý: `la-ban-du-lieu-YYYYMMDD.json` theo giờ máy.
String tenTepXuat(DateTime luc) {
  String hai(int v) => v.toString().padLeft(2, '0');
  return 'la-ban-du-lieu-${luc.year}${hai(luc.month)}${hai(luc.day)}.json';
}

/// Thư yêu cầu xoá dữ liệu phía máy chủ, điền sẵn mã thiết bị để đối chiếu.
/// Mã hoá thủ công (`%20`) - `Uri.queryParameters` dùng `+`, nhiều ứng dụng
/// thư hiện nguyên dấu cộng.
Uri thuYeuCauXoa({required String chuDe, required String noiDung}) => Uri.parse(
  'mailto:$thuRiengTu'
  '?subject=${Uri.encodeComponent(chuDe)}'
  '&body=${Uri.encodeComponent(noiDung)}',
);
