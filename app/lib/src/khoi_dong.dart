import 'package:compass_feature/compass_feature.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:la_ban/src/app.dart';
import 'package:la_ban/src/dinh_danh.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/luu_tru.dart';
import 'package:la_ban/src/phien_ban.dart';
import 'package:location_feature/location_feature.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:storage/storage.dart';

/// Điểm vào chung của mọi flavor. Màn chờ native giữ tới khung đầu, nên mở
/// kho trước `runApp` không làm nháy theme / màn giới thiệu.
Future<void> khoiDong(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  dangKyGiayPhepFont();
  dangKyGiayPhepDuLieu();
  runApp(await dungApp(flavor, dinhDanh: true));
}

/// Mở kho lưu trữ (canh gác crash -> cài đặt -> CSDL mã hoá) rồi dựng cây
/// app với các provider đã nối. Lỗi kho -> vẫn chạy, ở chế độ an toàn.
/// [ghiDeThem]: thay nguồn nền tảng khác trong test (ví dụ cảm biến).
/// [dinhDanh]: đăng ký thiết bị với API (S2) - tắt trong test (không mạng).
Future<Widget> dungApp(
  Flavor flavor, {
  KhoKhoa khoKhoa = const KhoKhoaNenTang(),
  bool nen = true,
  bool dinhDanh = false,
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
  final dv = kho != null && dinhDanh ? taoDichVuDinhDanh(flavor, kho) : null;
  if (dv != null) batDauDinhDanh(dv);
  return ProviderScope(
    overrides: [
      khoLuuTruProvider.overrideWithValue(kho),
      dichVuDinhDanhProvider.overrideWithValue(dv),
      if (kho != null) ...[
        khoCaiDatProvider.overrideWithValue(KhoCaiDatTep(kho.caiDat)),
        khoTuyChonLaBanProvider.overrideWithValue(
          KhoTuyChonLaBanTep(kho.laBan),
        ),
        khoViTriProvider.overrideWithValue(KhoViTriTep(kho.viTri)),
        // Vị trí lưu gần nhất: bắc thực có ngay khung đầu, không chờ GPS.
        viTriBanDauProvider.overrideWithValue(
          viTriTuTuyChon(KhoViTriTep(kho.viTri).doc()),
        ),
      ] else
        anToanProvider.overrideWithValue(LyDoAnToan.migrationLoi),
      ...ghiDeThem,
    ],
    child: LaBanApp(flavor: flavor),
  );
}
