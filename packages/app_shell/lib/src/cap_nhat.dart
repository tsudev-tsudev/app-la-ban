import 'package:app_shell/src/dinh_danh.dart';
import 'package:app_shell/src/kenh.dart';
import 'package:app_shell/src/phien_ban.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:network/network.dart';
import 'package:security_sdk/security_sdk.dart';

/// Mức nhắc cập nhật của bản đang chạy (Remote Config + bản APK mới nhất).
final capNhatProvider = Provider<CapNhat>((ref) {
  final ch = ref.watch(cauHinhTuXaProvider);
  return quyetDinhCapNhat(
    build: tachPhienBan(phienBanApp).build,
    toiThieu: ch?.toiThieu,
    khuyenNghi: ch?.khuyenNghi,
    banMoiNhat: ref.watch(tinhTrangProvider)?.banMoi?.maPhienBan,
  );
});

/// Người dùng bấm "Để sau" ở băng gợi ý - chỉ trong phiên này.
final boQuaCapNhatProvider = NotifierProvider<BoQuaCapNhat, bool>(
  BoQuaCapNhat.new,
);

class BoQuaCapNhat extends Notifier<bool> {
  @override
  bool build() => false;

  void boQua() => state = true;
}

/// Trang tải theo ngôn ngữ giao diện (bản ngoài Play - R0).
Uri trangTaiVe(Locale l) => Uri.parse(
  l.languageCode == 'vi'
      ? 'https://compass.tsudev.com/tai-ve'
      : 'https://compass.tsudev.com/en/download',
);

/// Mở trang tải; không mở được -> SnackBar chỉ đường.
Future<void> moTrangTai(
  BuildContext context, {
  Future<bool> Function(Uri) mo = moTrangLaBan,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final loi = context.l10n.updateOpenFailed;
  if (!await mo(trangTaiVe(Localizations.localeOf(context)))) {
    messenger?.showSnackBar(SnackBar(content: Text(loi)));
  }
}

/// Bọc toàn app (MaterialApp.builder): bắt buộc -> thay bằng màn chặn; khuyến
/// nghị -> băng gợi ý phía trên; không -> trả nguyên [child].
class KhungCapNhat extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muc = ref.watch(capNhatProvider);
    if (muc == CapNhat.batBuoc) return const ManCapNhatBatBuoc();
    if (muc == CapNhat.khong || ref.watch(boQuaCapNhatProvider)) return child;
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.4,
          ),
          child: SingleChildScrollView(
            child: BangCapNhat(
              phienBan: ref.watch(tinhTrangProvider)?.banMoi?.phienBan,
            ),
          ),
        ),
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

/// Băng gợi ý cập nhật (bỏ qua được).
class BangCapNhat extends ConsumerWidget {
  const new({this.phienBan, super.key});

  /// Phiên bản mới (từ `/v1/status`); null -> câu chung.
  final String? phienBan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = LbThemeExt.of(context).colors;
    final chu = Theme.of(context).textTheme;
    final pb = phienBan;
    return Material(
      key: const ValueKey('bang-cap-nhat'),
      color: Color.alphaBlend(c.primary.withValues(alpha: 0.16), c.surface),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.updateAvailableTitle, style: chu.titleSmall),
              const SizedBox(height: 4),
              Text(
                pb == null
                    ? l10n.updateAvailableBodyGeneric
                    : l10n.updateAvailableBody(pb),
                style: chu.bodyMedium,
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('cap-nhat-de-sau'),
                    onPressed: () =>
                        ref.read(boQuaCapNhatProvider.notifier).boQua(),
                    child: Text(l10n.updateLater),
                  ),
                  TextButton(
                    key: const ValueKey('cap-nhat-ngay'),
                    onPressed: () => moTrangTai(context),
                    child: Text(l10n.updateNow),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Màn chặn khi bản đang chạy dưới mức tối thiểu (lỗ hổng đã biết).
class ManCapNhatBatBuoc extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chu = Theme.of(context).textTheme;
    return Scaffold(
      key: const ValueKey('man-cap-nhat-bat-buoc'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const LbLogo(),
                  const SizedBox(height: 24),
                  Text(
                    l10n.updateRequiredTitle,
                    style: chu.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.updateRequiredBody,
                    style: chu.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('cap-nhat-bat-buoc'),
                    onPressed: () => moTrangTai(context),
                    child: Text(l10n.updateNow),
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
