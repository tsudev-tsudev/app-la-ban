import 'dart:async';
import 'dart:convert';

import 'package:freerasp/freerasp.dart';
import 'package:security_sdk/src/domain/rasp.dart';

/// Threat của freeRASP -> tín hiệu (khoá chi tiết `rasp_<tên>`). Switch đầy
/// đủ: freeRASP thêm loại mới thì không biên dịch được -> phải ánh xạ.
TinHieu tinHieuTuThreat(Threat t) {
  final loai = switch (t) {
    Threat.hooks => LoaiTinHieu.hookFrida,
    Threat.debug => LoaiTinHieu.debugger,
    Threat.passcode => LoaiTinHieu.khongKhoaMan,
    Threat.deviceId => LoaiTinHieu.doiMaThietBi,
    Threat.simulator => LoaiTinHieu.emulator,
    Threat.appIntegrity => LoaiTinHieu.dongGoiLai,
    Threat.obfuscationIssues => LoaiTinHieu.loiLamRoi,
    Threat.deviceBinding => LoaiTinHieu.rangBuocThietBi,
    Threat.unofficialStore => LoaiTinHieu.nguonCaiNgoai,
    Threat.privilegedAccess => LoaiTinHieu.root,
    Threat.secureHardwareNotAvailable => LoaiTinHieu.khongPhanCungAnToan,
    Threat.systemVPN => LoaiTinHieu.vpn,
    Threat.devMode => LoaiTinHieu.cheDoNhaPhatTrien,
    Threat.adbEnabled => LoaiTinHieu.adb,
    Threat.screenshot || Threat.screenRecording => LoaiTinHieu.quayChupMan,
    Threat.multiInstance => LoaiTinHieu.nhanBanApp,
    Threat.unsecureWiFi => LoaiTinHieu.wifiKhongAnToan,
    Threat.timeSpoofing => LoaiTinHieu.giaGio,
    Threat.locationSpoofing => LoaiTinHieu.giaViTri,
    Threat.automation => LoaiTinHieu.tuDongHoa,
    Threat.bootloader => LoaiTinHieu.moKhoaBootloader,
  };
  final ten = t.name.replaceAllMapped(
    RegExp('[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );
  return (loai: loai, chiTiet: {'rasp_$ten': true});
}

/// Cấu hình freeRASP (QUYET_DINH Q13). [chungChi]: SHA-256 hex chứng chỉ
/// ký hợp lệ; [goi]: applicationId của flavor.
TalsecConfig cauHinhFreeRasp({
  required String goi,
  required List<String> chungChi,
  required bool banThat,
}) => TalsecConfig(
  androidConfig: AndroidConfig(
    packageName: goi,
    signingCertHashes: [
      for (final h in chungChi) base64.encode(_hexSangByte(h)),
    ],
  ),
  watcherMail: 'security@tsudev.com',
  isProd: banThat,
);

List<int> _hexSangByte(String hex) => [
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

/// Khởi động freeRASP và chuyển mọi phát hiện thành [TinHieu]. Lỗi khởi động
/// (nền tảng chưa hỗ trợ, cấu hình sai) không làm hỏng app - chỉ mất một
/// nguồn tín hiệu, kiểm tra native vẫn chạy.
Stream<TinHieu> nguonFreeRasp(TalsecConfig cauHinh) {
  late final StreamController<TinHieu> ra;
  StreamSubscription<Threat>? nghe;
  ra = StreamController<TinHieu>(
    onListen: () async {
      try {
        nghe = Talsec.instance.onThreatDetected.listen(
          (t) => ra.add(tinHieuTuThreat(t)),
          onError: (Object _) {},
        );
        await Talsec.instance.start(cauHinh);
      } on Object {
        await nghe?.cancel();
        await ra.close();
      }
    },
    onCancel: () => nghe?.cancel(),
  );
  return ra.stream;
}
