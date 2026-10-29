/// Mức nhắc cập nhật (Spec §8: Force / Soft update).
enum CapNhat {
  khong,

  /// Có bản mới hoặc dưới mức khuyến nghị: gợi ý, bỏ qua được.
  khuyenNghi,

  /// Dưới mức tối thiểu (lỗ hổng đã biết): chặn app tới khi cập nhật.
  batBuoc,
}

/// [build] của app so với Remote Config ([toiThieu], [khuyenNghi]) và bản
/// APK mới nhất server báo ([banMoiNhat], bản tải ngoài Play chưa tự cập
/// nhật được). Thiếu thông tin -> không nhắc.
CapNhat quyetDinhCapNhat({
  required int build,
  int? toiThieu,
  int? khuyenNghi,
  int? banMoiNhat,
}) {
  if (toiThieu != null && build < toiThieu) return CapNhat.batBuoc;
  if (khuyenNghi != null && build < khuyenNghi) return CapNhat.khuyenNghi;
  if (banMoiNhat != null && build < banMoiNhat) return CapNhat.khuyenNghi;
  return CapNhat.khong;
}
