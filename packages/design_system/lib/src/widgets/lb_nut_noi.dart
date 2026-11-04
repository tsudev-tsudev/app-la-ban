import 'package:design_system/src/icons/lb_icon.dart';
import 'package:design_system/src/icons/lb_icon_data.dart';
import 'package:design_system/src/theme/lb_theme.dart';
import 'package:flutter/material.dart';

/// Nút nổi KHÔNG nền (Q60): chỉ icon (+ nhãn), vùng chạm >= 48 dp. Đặt trên
/// bản đồ / nội dung bất kỳ nên có quầng sáng mờ màu nền phía sau icon và
/// bóng chữ cho nhãn - đủ tương phản mà không thành "nút khối".
class LbNutNoi extends StatelessWidget {
  const new({
    required this.icon,
    required this.nhan,
    required this.onPressed,
    this.hienNhan = true,
    super.key,
  });

  final LbIconData icon;

  /// Nhãn (cũng là tooltip / nhãn trợ năng).
  final String nhan;
  final VoidCallback? onPressed;

  /// false: chỉ icon (nhãn vẫn là tooltip + trợ năng).
  final bool hienNhan;

  /// Cạnh vùng chạm tối thiểu.
  static const vungCham = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nen = theme.colorScheme.surface;
    final mau = onPressed == null
        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
        : LbThemeExt.of(context).colors.primaryDeep;
    final quang = BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [nen.withValues(alpha: 0.95), nen.withValues(alpha: 0)],
      ),
    );
    final kieu = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: nhan,
      excludeSemantics: true,
      child: Tooltip(
        message: nhan,
        excludeFromSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          radius: vungCham * 0.75,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: vungCham,
              minHeight: vungCham,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: quang,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: LbIcon(icon, size: 28, color: mau),
                    ),
                  ),
                  // Viền chữ đặc màu nền (vẽ dưới) - đọc được cả khi đè lên
                  // chữ / đường của bản đồ (bóng mờ không đủ - thử trên M32).
                  if (hienNhan)
                    Stack(
                      children: [
                        Text(
                          nhan,
                          textAlign: TextAlign.center,
                          style: kieu?.copyWith(
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 4
                              ..strokeJoin = StrokeJoin.round
                              ..color = nen,
                          ),
                        ),
                        Text(
                          nhan,
                          textAlign: TextAlign.center,
                          style: kieu?.copyWith(color: mau),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
