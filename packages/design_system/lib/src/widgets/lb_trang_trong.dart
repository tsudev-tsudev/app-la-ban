import 'package:design_system/src/tokens/tokens.g.dart';
import 'package:flutter/material.dart';

/// Nội dung đặt giữa màn hình (hình + tiêu đề + mô tả), tự cuộn khi màn
/// thấp / chữ lớn để không tràn. Dùng cho trạng thái trống và màn tạm.
class LbTrangTrong extends StatelessWidget {
  const new({required this.hinh, this.tieuDe, this.moTa, super.key});

  /// Hình minh hoạ (icon / logo), đã có kích thước.
  final Widget hinh;

  final String? tieuDe;
  final String? moTa;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, rang) => SingleChildScrollView(
        padding: const EdgeInsets.all(LbSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: rang.maxHeight - 2 * LbSpacing.lg,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
