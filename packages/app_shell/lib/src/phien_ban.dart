/// Phiên bản app đang chạy (`version:` của app/pubspec.yaml hoặc
/// app_pro/pubspec.yaml - M2, Q56). Gán MỘT lần ở `dungApp` từ
/// `CauHinhSanPham.phienBan`, trước khi dựng dịch vụ nào; giá trị mặc định chỉ
/// cho test dựng widget lẻ không qua `dungApp`.
String get phienBanApp => _phienBan;
String _phienBan = '0.0.0+1';

/// Đặt phiên bản (chỉ `dungApp` gọi).
set phienBanApp(String v) => _phienBan = v;
