import 'package:design_system/src/icons/lb_icon_data.dart';
import 'package:flutter/widgets.dart';

/// Vẽ một icon 24dp của bộ `LbIcons` bằng nét (độ dày = size / 12, đầu và góc tròn).
///
/// Cỡ và màu mặc định lấy từ [IconTheme] như `Icon` của Flutter.
class LbIcon extends StatelessWidget {
  const new(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final LbIconData icon;

  /// Cạnh hộp vuông (dp). Null -> `IconTheme.size` (mặc định 24).
  final double? size;

  /// Màu nét. Null -> `IconTheme.color`.
  final Color? color;

  /// Nhãn cho trình đọc màn hình (chuỗi đã dịch; null = trang trí).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final canh = size ?? theme.size ?? 24;
    final mau = color ?? theme.color ?? const Color(0xFF000000);
    final opacity = theme.opacity ?? 1;
    final ve = CustomPaint(
      size: Size.square(canh),
      painter: LbIconPainter(icon, mau.withValues(alpha: mau.a * opacity)),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: ve);
    return Semantics(label: semanticLabel, image: true, child: ve);
  }
}

/// Painter của [LbIcon]: co khung 24 x 24 về [Size] thật.
class LbIconPainter extends CustomPainter {
  const new(this.icon, this.color);

  final LbIconData icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final tiLe = size.shortestSide / 24;
    canvas
      ..save()
      ..translate((size.width - 24 * tiLe) / 2, (size.height - 24 * tiLe) / 2)
      ..scale(tiLe)
      ..drawPath(
        icon.taoPath(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(LbIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}
