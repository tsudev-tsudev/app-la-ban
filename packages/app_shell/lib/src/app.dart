import 'package:app_shell/src/cap_nhat.dart';
import 'package:app_shell/src/cong_truc_tuyen.dart';
import 'package:app_shell/src/flavor.dart';
import 'package:app_shell/src/lam_cung.dart';
import 'package:app_shell/src/router.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:settings_feature/settings_feature.dart';

/// Gốc ứng dụng (đặt trong `ProviderScope`). Chỉ `select` ngôn ngữ và chế độ
/// sáng / tối: đổi hai giá trị này dựng lại MaterialApp nhưng router, vị trí
/// và state từng tab giữ nguyên.
class LaBanApp extends ConsumerWidget {
  const new({required this.cauHinh, super.key});

  /// Môi trường + sản phẩm (miễn phí / Pro) đang chạy.
  final CauHinhSanPham cauHinh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ma = ref.watch(caiDatProvider.select((c) => c.ngonNgu.maNgonNgu));
    final cheDo = ref.watch(caiDatProvider.select((c) => c.cheDo));
    // Đồng ý / rút đồng ý (màn giới thiệu, Quyền riêng tư) -> mở / đóng cổng
    // dịch vụ trực tuyến ngay, không dựng lại cây.
    ref.listen(
      caiDatProvider.select((c) => c.trucTuyen),
      (_, v) => ref.read(congTrucTuyenProvider)?.value = v,
    );
    return MaterialApp.router(
      onGenerateTitle: (c) => switch (cauHinh) {
        CauHinhSanPham(flavor: Flavor.prod, laPro: false) => c.l10n.appTitle,
        CauHinhSanPham(flavor: Flavor.prod, laPro: true) => c.l10n.appTitlePro,
        _ => cauHinh.appName,
      },
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      // Khoá / hạn chế theo Risk Level (S4) rồi cập nhật bắt buộc /
      // khuyến nghị (S3) phủ trên mọi màn.
      builder: (_, child) =>
          KhungRuiRo(child: KhungCapNhat(child: child ?? const SizedBox())),
      theme: LbTheme.light,
      darkTheme: LbTheme.dark,
      themeMode: switch (cheDo) {
        CheDoGiaoDien.heThong => ThemeMode.system,
        CheDoGiaoDien.sang => ThemeMode.light,
        CheDoGiaoDien.toi => ThemeMode.dark,
      },
      locale: ma == null ? null : Locale(ma),
      supportedLocales: LbNgonNgu.hoTro,
      localeListResolutionCallback: (ds, _) => LbNgonNgu.chon(ds),
      localizationsDelegates: const [
        LbL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
