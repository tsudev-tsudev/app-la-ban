import 'package:design_system/src/tokens/tokens.g.dart';

/// Lớp bố cục theo cạnh rộng cửa sổ (Material 3 window size class).
enum LbKichCo {
  /// < 600dp: điện thoại dọc - thanh điều hướng dưới.
  compact,

  /// 600..839dp: điện thoại ngang, máy tính bảng nhỏ - rail.
  medium,

  /// >= 840dp: máy tính bảng lớn - rail mở rộng có nhãn.
  expanded;

  /// Lớp bố cục cho cạnh rộng [rong] (dp). Giá trị âm / NaN coi như compact.
  static LbKichCo tuRong(double rong) {
    if (!(rong >= LbBreakpoint.medium)) return LbKichCo.compact;
    if (rong < LbBreakpoint.expanded) return LbKichCo.medium;
    return LbKichCo.expanded;
  }
}
