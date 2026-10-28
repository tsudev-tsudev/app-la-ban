import 'dart:ui';

/// Ngôn ngữ giao diện app hỗ trợ.
abstract final class LbNgonNgu {
  static const vi = Locale('vi');
  static const en = Locale('en');

  /// Pseudo-locale chỉ dùng trong test giao diện (chữ có dấu, dài thêm ~40%).
  static const gia = Locale('en', 'XA');

  /// Ngôn ngữ người dùng chọn được (không có [gia]).
  static const hoTro = <Locale>[vi, en];

  /// Chọn ngôn ngữ app khi để "Theo hệ thống": ngôn ngữ đầu tiên trong danh
  /// sách ưu tiên của thiết bị mà app hỗ trợ; không khớp ngôn ngữ nào -> en.
  /// [gia] chỉ được chọn khi khớp đúng cả mã vùng (test truyền vào trực tiếp).
  static Locale chon(List<Locale>? thietBi) {
    for (final l in thietBi ?? const <Locale>[]) {
      if (l == gia) return gia;
      for (final h in hoTro) {
        if (l.languageCode == h.languageCode) return h;
      }
    }
    return en;
  }
}
