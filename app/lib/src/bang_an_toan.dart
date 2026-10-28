import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:la_ban/src/luu_tru.dart';
import 'package:storage/storage.dart';

/// Đặt [BangAnToan] trên [child] khi đang ở chế độ an toàn; chạy thường thì
/// trả nguyên [child] (cây widget, golden không đổi).
class KhungAnToan extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyDo = ref.watch(anToanProvider);
    if (lyDo == null) return child;
    return Column(
      children: [
        // Máy nhỏ + chữ lớn: băng không chiếm quá 40% màn, phần dư tự cuộn.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.4,
          ),
          child: SingleChildScrollView(child: BangAnToan(lyDo: lyDo)),
        ),
        // Băng đã chiếm phần tai thỏ / thanh trạng thái phía trên.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Băng báo chế độ an toàn (Spec §10.4). La bàn luôn dùng được, dữ liệu cũ
/// không bị đụng.
class BangAnToan extends ConsumerWidget {
  const new({required this.lyDo, super.key});

  final LyDoAnToan lyDo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kho = ref.watch(khoLuuTruProvider);
    final c = LbThemeExt.of(context).colors;
    final chu = Theme.of(context).textTheme;
    return Material(
      key: const ValueKey('bang-an-toan'),
      // Vàng cảnh báo pha nhạt trên nền: chữ giữ màu chữ chính (đạt AA).
      color: Color.alphaBlend(c.warning.withValues(alpha: 0.22), c.surface),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LbIcon(LbIcons.khien, color: c.warningStrong),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.safeModeTitle, style: chu.titleSmall),
                    const SizedBox(height: 4),
                    Text(switch (lyDo) {
                      LyDoAnToan.crashLienTiep => l10n.safeModeCrash,
                      LyDoAnToan.migrationLoi => l10n.safeModeStorage,
                      LyDoAnToan.csdlMoiHon => l10n.safeModeNewer,
                    }, style: chu.bodyMedium),
                    if (lyDo == LyDoAnToan.crashLienTiep && kho != null)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: const ValueKey('thu-che-do-thuong'),
                          onPressed: () {
                            kho.thoatCheDoAnToan();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.safeModeRetryDone)),
                            );
                          },
                          child: Text(l10n.safeModeRetry),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thay màn của tính năng đang tắt bằng cờ (an toàn / kill-switch).
class ManTamTat extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        context.l10n.featurePaused,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}
