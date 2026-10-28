import 'package:compass_feature/compass_feature.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:la_ban/src/app.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/luu_tru.dart';
import 'package:la_ban/src/phien_ban.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:storage/storage.dart';

/// Điểm vào chung của mọi flavor. Màn chờ native giữ tới khung đầu, nên mở
/// kho trước `runApp` không làm nháy theme / màn giới thiệu.
Future<void> khoiDong(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  dangKyGiayPhepFont();
  runApp(await dungApp(flavor));
}

/// Mở kho lưu trữ (canh gác crash -> cài đặt -> CSDL mã hoá) rồi dựng cây
/// app với các provider đã nối. Lỗi kho -> vẫn chạy, ở chế độ an toàn.
/// [ghiDeThem]: thay nguồn nền tảng khác trong test (ví dụ cảm biến).
Future<Widget> dungApp(
  Flavor flavor, {
  KhoKhoa khoKhoa = const KhoKhoaNenTang(),
  bool nen = true,
  List<Override> ghiDeThem = const [],
}) async {
  KhoLuuTru? kho;
  try {
    kho = await KhoLuuTru.mo(
      phienBanApp: phienBanApp,
      khoKhoa: khoKhoa,
      nen: nen,
    );
  } on Object {
    kho = null;
  }
  if (kho != null) theoDoiOnDinh(kho.danhDauOnDinh);
  return ProviderScope(
    overrides: [
      khoLuuTruProvider.overrideWithValue(kho),
      if (kho != null) ...[
        khoCaiDatProvider.overrideWithValue(KhoCaiDatTep(kho.caiDat)),
        khoTuyChonLaBanProvider.overrideWithValue(
          KhoTuyChonLaBanTep(kho.laBan),
        ),
      ] else
        anToanProvider.overrideWithValue(LyDoAnToan.migrationLoi),
      ...ghiDeThem,
    ],
    child: LaBanApp(flavor: flavor),
  );
}
