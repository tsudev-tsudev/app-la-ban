import 'dart:math' as math;

import 'package:design_system/src/tokens/tokens.g.dart';
import 'package:flutter/material.dart';

/// Nội dung đặt giữa màn hình (hình + tiêu đề + mô tả), tự cuộn khi màn
/// thấp / chữ lớn để không tràn. Dùng cho trạng thái trống và màn tạm.
class LbTrangTrong extends StatelessWidget {
  const new({required this.hinh, this.tieuDe, this.moTa, this.duoi, super.key});

  /// Hình minh hoạ (icon / logo), đã có kích thước.
  final Widget hinh;

  final String? tieuDe;
  final String? moTa;

  /// Phần thêm dưới mô tả (nút hành động, tiến trình...).
  final Widget? duoi;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, rang) => SingleChildScrollView(
        padding: const EdgeInsets.all(LbSpacing.lg),
        child: ConstrainedBox(
          // Vùng thấp hơn phần đệm (băng an toàn + chữ x2 trên máy nhỏ) ->
          // không ép chiều cao tối thiểu âm.
          constraints: BoxConstraints(
            minHeight: math.max(0, rang.maxHeight - 2 * LbSpacing.lg),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  hinh,
                  if (tieuDe != null) ...[
                    const SizedBox(height: LbSpacing.lg),
                    Text(
                      tieuDe!,
                      style: chu.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (moTa != null) ...[
                    const SizedBox(height: LbSpacing.xs),
                    Text(
                      moTa!,
                      style: chu.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (duoi != null) ...[
                    const SizedBox(height: LbSpacing.lg),
                    duoi!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
