import 'package:compass_feature/compass_feature.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:la_ban/src/app.dart';
import 'package:la_ban/src/ar.dart';
import 'package:la_ban/src/ban_do.dart';
import 'package:la_ban/src/bao_loi.dart';
import 'package:la_ban/src/cong_truc_tuyen.dart';
import 'package:la_ban/src/diem.dart';
import 'package:la_ban/src/dinh_danh.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/kenh.dart';
import 'package:la_ban/src/lam_cung.dart';
import 'package:la_ban/src/luu_tru.dart';
import 'package:la_ban/src/phien_ban.dart';
import 'package:la_ban/src/rieng_tu.dart';
import 'package:location_feature/location_feature.dart';
import 'package:map_feature/map_feature.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:storage/storage.dart';

/// Điểm vào chung của mọi flavor. Màn chờ native giữ tới khung đầu, nên mở
/// kho trước `runApp` không làm nháy theme / màn giới thiệu.
Future<void> khoiDong(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  dangKyGiayPhepFont();
  dangKyGiayPhepDuLieu();
  dangKyGiayPhepBanDo();
  dangKyGiayPhepLuuTru();
  runApp(await dungApp(flavor, dinhDanh: true));
}

/// Mở kho lưu trữ (canh gác crash -> cài đặt -> CSDL mã hoá) rồi dựng cây
/// app với các provider đã nối. Lỗi kho -> vẫn chạy, ở chế độ an toàn.
/// [ghiDeThem]: thay nguồn nền tảng khác trong test (ví dụ cảm biến).
/// [dinhDanh]: đăng ký thiết bị + kênh ký số với API (S2, S3) - tắt trong
/// test (không mạng).
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
  final kenh = kho != null && dinhDanh ? KenhApp.tao(flavor, kho) : null;
  final dv = kho != null && kenh != null
      ? taoDichVuDinhDanh(kho, kenh.apiGhim)
      : null;
  // A8a: chỉ gọi máy chủ khi người dùng đồng ý (Q43) - app.dart đồng bộ cổng
  // theo cài đặt, đồng ý muộn ở màn giới thiệu thì dịch vụ chạy lúc đó.
  final cong = kenh == null
      ? null
      : CongTrucTuyen(mo: KhoCaiDatTep(kho!.caiDat).doc().trucTuyen);
  if (dv != null) batDauDinhDanh(dv, cong!);
  // S10b: báo cáo sự cố tự xây (Q49) - chỉ ghi / gửi khi người dùng bật công
  // tắc riêng trong Quyền riêng tư VÀ đã đồng ý trực tuyến.
  if (kho != null && dinhDanh) {
    final caiDat = KhoCaiDatTep(kho.caiDat);
    bool duoc() => caiDat.doc().guiBaoLoi;
    final hang = HangBaoLoi(TepJson.mo('${kho.thuMuc}/bao_cao_loi.json'));
    batLoi(hang, duoc, phienBanApp);
    if (dv != null) batDauGuiBaoLoi(hang, dv, cong!, duoc);
  }
  if (kenh != null) batDauKenh(kenh, dv, cong!);
  // S4: kiểm tra môi trường + freeRASP, chỉ báo server (SEC-APP).
  final rasp = kho != null && dv != null ? taoDichVuRasp(kho, dv) : null;
  if (rasp != null) batDauRasp(rasp, flavor, cong!, dinhDanh: dv, kenh: kenh);
  return ProviderScope(
    overrides: [
      khoLuuTruProvider.overrideWithValue(kho),
      dichVuDinhDanhProvider.overrideWithValue(dv),
      kenhProvider.overrideWithValue(kenh),
      dichVuRaspProvider.overrideWithValue(rasp),
      congTrucTuyenProvider.overrideWithValue(cong),
      if (kho != null && dinhDanh)
        khoaDaLuuProvider.overrideWithValue(docKhoaDaLuu(kho)),
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
      ...noiDiem(kho),
      ...noiBanDo(flavor),
      ...noiAr(),
      ...noiRiengTu(kho),
      ...ghiDeThem,
    ],
    child: LaBanApp(flavor: flavor),
  );
}
