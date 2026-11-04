import 'dart:ui' as ui;

import 'package:design_system/src/tokens/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        ? ColoredBox(
            color: theme.colorScheme.surface,
            child: const SizedBox.expand(),
          )
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
                // Không có con thì DecoratedBox co về 0x0 -> header trong
                // suốt hoàn toàn (thấy trên M32).
                child: const SizedBox.expand(),
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
      // Nền trong suốt -> Android tự chọn icon thanh trạng thái sáng (mất trên
      // nền sáng, phát hiện trên M32). Đặt theo chủ đề.
      systemOverlayStyle:
          (toi ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
      flexibleSpace: nen,
    );
  }
}
