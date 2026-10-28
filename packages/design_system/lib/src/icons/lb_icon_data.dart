import 'dart:ui';

/// Một icon 24dp: hàm dựng [Path] trong khung 24 x 24 (sinh từ `design/icons/*.svg`).
final class LbIconData {
  /// [ten] là tên tệp SVG (không đuôi), [ve] thêm các nét vào Path.
  const new(this.ten, this.ve);

  /// Tên tệp nguồn, ví dụ `ghim-gps`.
  final String ten;

  /// Thêm nét của icon vào [Path] (toạ độ 0..24).
  final void Function(Path p) ve;

  /// Path mới của icon trong khung 24 x 24.
  Path taoPath() {
    final p = Path();
    ve(p);
    return p;
  }

  @override
  String toString() => 'LbIconData($ten)';
}
