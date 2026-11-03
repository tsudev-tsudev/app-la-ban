import 'dart:ui' as ui;

import 'package:design_system/src/tokens/tokens.g.dart';
import 'package:flutter/material.dart';

/// Header mờ (Q60): nền kính BackdropFilter + lớp phủ màu kính khi nội dung
/// cuộn bên dưới. Reduce motion hoặc máy yếu ([tatMo]) -> nền đặc, không blur
/// (blur tốn GPU). Dùng với `Scaffold(extendBodyBehindAppBar: true)` và cộng
/// `MediaQuery.paddingOf(context).top` vào phần đệm trên của danh sách.
class LbHeaderMo extends StatelessWidget implements PreferredSizeWidget {
  const new({
    required this.title,
    this.actions = const [],
    this.tatMo = false,
    super.key,
  });

  final Widget title;
  final List<Widget> actions;

  /// Tắt blur (máy yếu / chế độ nhẹ).
  final bool tatMo;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toi = theme.brightness == Brightness.dark;
    final kinh = toi ? LbGlass.dark : LbGlass.light;
    final dac =
        tatMo || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final nen = dac
        ? ColoredBox(color: theme.colorScheme.surface)
        : ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: LbGlass.blur,
                sigmaY: LbGlass.blur,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kinh.fill,
                  border: Border(bottom: BorderSide(color: kinh.border)),
                ),
              ),
            ),
          );
    return AppBar(
      title: title,
      actions: actions,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      flexibleSpace: nen,
    );
  }
}
