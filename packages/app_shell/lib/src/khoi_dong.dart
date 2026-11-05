import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_shell/src/app.dart';
import 'package:app_shell/src/ar.dart';
import 'package:app_shell/src/ban_do.dart';
import 'package:app_shell/src/bao_loi.dart';
import 'package:app_shell/src/cong_truc_tuyen.dart';
import 'package:app_shell/src/diem.dart';
import 'package:app_shell/src/dinh_danh.dart';
import 'package:app_shell/src/flavor.dart';
import 'package:app_shell/src/kenh.dart';
import 'package:app_shell/src/lam_cung.dart';
import 'package:app_shell/src/luu_tru.dart';
import 'package:app_shell/src/phat_trien.dart';
import 'package:app_shell/src/phien_ban.dart';
import 'package:app_shell/src/pro.dart';
import 'package:app_shell/src/rieng_tu.dart';
import 'package:compass_feature/compass_feature.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:location_feature/location_feature.dart';
import 'package:map_feature/map_feature.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:storage/storage.dart';

/// Điểm vào chung của mọi flavor. Màn chờ native giữ tới khung đầu, nên mở
/// kho trước `runApp` không làm nháy theme / màn giới thiệu.
Future<void> khoiDong(CauHinhSanPham cauHinh) async {
  WidgetsFlutterBinding.ensureInitialized();
  dangKyGiayPhepFont();
  dangKyGiayPhepDuLieu();
  dangKyGiayPhepBanDo();
  dangKyGiayPhepLuuTru();
  runApp(await dungApp(cauHinh, dinhDanh: true));
}

/// Mở kho lưu trữ (canh gác crash -> cài đặt -> CSDL mã hoá) rồi dựng cây
/// app với các provider đã nối. Lỗi kho -> vẫn chạy, ở chế độ an toàn.
/// [ghiDeThem]: thay nguồn nền tảng khác trong test (ví dụ cảm biến).
/// [dinhDanh]: đăng ký thiết bị + kênh ký số với API (S2, S3) - tắt trong
/// test (không mạng).
Future<Widget> dungApp(
  CauHinhSanPham cauHinh, {
  KhoKhoa khoKhoa = const KhoKhoaNenTang(),
  bool nen = true,
  bool dinhDanh = false,
  List<Override> ghiDeThem = const [],
}) async {
  phienBanApp = cauHinh.phienBan;
  final flavor = cauHinh.flavor;
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
  // S11 (Q57): theo dõi Developer options cả khi chưa đồng ý trực tuyến (màn
  // chặn cục bộ không cần mạng); báo server chỉ khi cổng trực tuyến mở.
  final phatTrien = dinhDanh ? GiamSatPhatTrien() : null;
  if (kenh != null) {
    batDauKenh(kenh, dv, cong!, phatTrien: () => phatTrien!.hienTai);
    phatTrien!.khiDoi = (moi) {
      if (!moi.bat) kenh.boChanMayChu();
      if (cong.value) unawaited(kenh.lamMoi(dv, phatTrien: moi));
    };
  }
  phatTrien?.batDau();
  // S4: kiểm tra môi trường + freeRASP, chỉ báo server (SEC-APP).
  final rasp = kho != null && dv != null ? taoDichVuRasp(kho, dv) : null;
  if (rasp != null) {
    batDauRasp(rasp, cauHinh.goi, cong!, dinhDanh: dv, kenh: kenh);
  }
  // M1a bước 2: quyền lợi Pro + Play Billing (Android) - server quyết (Q55).
  final pro = kho != null && dv != null && Platform.isAndroid
      ? taoDichVuQuyenLoi(
          cauHinh: cauHinh,
          kho: kho,
          dinhDanh: dv,
          kenh: kenh!,
          cong: cong!,
        )
      : null;
  return ProviderScope(
    overrides: [
      khoLuuTruProvider.overrideWithValue(kho),
      dichVuDinhDanhProvider.overrideWithValue(dv),
      kenhProvider.overrideWithValue(kenh),
      giamSatPhatTrienProvider.overrideWithValue(phatTrien),
      banProdProvider.overrideWithValue(flavor == Flavor.prod),
      cauHinhSanPhamProvider.overrideWithValue(cauHinh),
      dichVuRaspProvider.overrideWithValue(rasp),
      congTrucTuyenProvider.overrideWithValue(cong),
      // R3b: vị trí giả (Location.isMock) -> tín hiệu MOCK_LOCATION, chỉ báo.
      if (rasp != null)
        baoViTriGiaProvider.overrideWithValue(baoViTriGia(rasp, cong!)),
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
      ...noiPro(
        pro,
        cauHinh,
        dv,
        lamMoi: kenh == null
            ? null
            : () => kenh.lamMoi(dv, phatTrien: phatTrien?.hienTai),
      ),
      ...ghiDeThem,
    ],
    child: LaBanApp(cauHinh: cauHinh),
  );
}
