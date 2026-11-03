import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:la_ban/src/kenh.dart';
import 'package:security_sdk/security_sdk.dart';

/// Theo dõi Developer options / USB / Wireless debugging (S11, QUYET_DINH
/// Q57): đọc khi mở app, mỗi lần quay lại foreground, mỗi [khoangChan] khi
/// đang bật (người dùng tắt bằng ô Cài đặt nhanh vẫn thấy ngay) và mỗi
/// [khoangNen] khi sạch. Đọc Settings.Global < 1 ms, không cần quyền.
final class GiamSatPhatTrien extends ChangeNotifier {
  new({
    this.kenh = const KenhPhatTrienKenh(),
    this.khoangChan = const Duration(seconds: 2),
    this.khoangNen = const Duration(minutes: 1),
  });

  final KenhPhatTrien kenh;
  final Duration khoangChan;
  final Duration khoangNen;

  /// Gọi khi trạng thái đổi (kênh báo server ngay, không chờ nhịp 15 phút).
  void Function(TrangThaiPhatTrien moi)? khiDoi;

  TrangThaiPhatTrien _hienTai = TrangThaiPhatTrien.sach;
  TrangThaiPhatTrien get hienTai => _hienTai;

  Timer? _hen;
  AppLifecycleListener? _vongDoi;
  bool _dong = false;

  void batDau() {
    _vongDoi ??= AppLifecycleListener(
      onResume: () => unawaited(kiem()),
      onPause: () => _hen?.cancel(),
    );
    unawaited(kiem());
  }

  Future<void> kiem() async {
    final moi = await kenh.doc();
    if (_dong) return;
    if (moi != _hienTai) {
      _hienTai = moi;
      notifyListeners();
      khiDoi?.call(moi);
    }
    _hen?.cancel();
    _hen = Timer(moi.bat ? khoangChan : khoangNen, () => unawaited(kiem()));
  }

  /// Dừng hẹn giờ kiểm lại (test / khi huỷ).
  void dung() => _hen?.cancel();

  @override
  void dispose() {
    _dong = true;
    _hen?.cancel();
    _vongDoi?.dispose();
    super.dispose();
  }
}

/// Bộ theo dõi của lần chạy (null: test / chế độ an toàn không bật).
final giamSatPhatTrienProvider = Provider<GiamSatPhatTrien?>((_) => null);

/// true: bản prod (Q57 - dev / staging chỉ ghi nhận để thử qua ADB).
final banProdProvider = Provider<bool>((_) => false);

final phatTrienCucBoProvider = Provider<TrangThaiPhatTrien>((ref) {
  final g = ref.watch(giamSatPhatTrienProvider);
  if (g == null) return TrangThaiPhatTrien.sach;
  void doi() => ref.invalidateSelf();
  g.addListener(doi);
  ref.onDispose(() => g.removeListener(doi));
  return g.hienTai;
});

/// Hiện màn chặn toàn phần: máy đang bật HOẶC Worker báo đang chặn; tắt từ xa
/// bằng `chanDevMode` trong `tat` của Remote Config ký số.
final chanPhatTrienProvider = Provider<bool>(
  (ref) => canChanPhatTrien(
    cucBo: ref.watch(phatTrienCucBoProvider),
    banProd: ref.watch(banProdProvider),
    mayChuBao: ref.watch(tinhTrangProvider)?.cheDoPhatTrien ?? false,
    tatTuXa: ref.watch(cauHinhTuXaProvider)?.tat ?? const {},
  ),
);

/// Màn chặn khi bật chế độ Nhà phát triển: không chạy tiếp tính năng nào,
/// chỉ hướng dẫn tắt + mở thẳng Tùy chọn nhà phát triển + kiểm tra lại.
class ManChanPhatTrien extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ManChanPhatTrien> createState() => _ManChanPhatTrienState();
}

class _ManChanPhatTrienState extends ConsumerState<ManChanPhatTrien> {
  bool _dangKiem = false;

  Future<void> _kiemLai() async {
    final g = ref.read(giamSatPhatTrienProvider);
    if (g == null || _dangKiem) return;
    setState(() => _dangKiem = true);
    await g.kiem();
    if (mounted) setState(() => _dangKiem = false);
  }

  Future<void> _moCaiDat() async {
    final g = ref.read(giamSatPhatTrienProvider);
    final mo = await (g?.kenh ?? const KenhPhatTrienKenh()).moCaiDat();
    if (!mo && mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.devModeOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chu = Theme.of(context).textTheme;
    final mau = Theme.of(context).colorScheme;
    final cb = ref.watch(phatTrienCucBoProvider);
    final dong = [
      if (cb.devMode) l10n.devModeItemOptions,
      if (cb.adb) l10n.devModeItemUsb,
      if (cb.adbWifi) l10n.devModeItemWifi,
    ];
    return ScaffoldMessenger(
      child: Scaffold(
        key: const ValueKey('man-chan-phat-trien'),
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
                      l10n.devModeBlockedTitle,
                      style: chu.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.devModeBlockedBody,
                      style: chu.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Chỗ dành sẵn cố định: danh sách rỗng (chỉ máy chủ còn
                    // ghi nhận) vẫn giữ một dòng, nút không nhảy khi đổi.
                    Semantics(
                      liveRegion: true,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.devModeStatusTitle,
                                style: chu.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              if (dong.isEmpty)
                                Text(
                                  l10n.devModeServerOnly,
                                  style: chu.bodyMedium,
                                )
                              else
                                for (final d in dong)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.toggle_on,
                                          color: mau.error,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(d, style: chu.bodyMedium),
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.devModeHowTo,
                      style: chu.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const ValueKey('mo-cai-dat-phat-trien'),
                      onPressed: _moCaiDat,
                      icon: const Icon(Icons.settings_outlined),
                      label: Text(l10n.devModeOpenSettings),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const ValueKey('kiem-lai-phat-trien'),
                      onPressed: _dangKiem ? null : _kiemLai,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.devModeRecheck),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
