import 'package:security_sdk/src/domain/phien.dart';

/// Tín hiệu môi trường không tin cậy (Spec §7.3b, SEC-APP APP-02). Mỗi tín
/// hiệu ánh xạ tới MỘT loại sự kiện của bảng điểm server (Spec §7.6c) - app
/// không tự chấm điểm, không tự chặn: server quyết định (Q8).
enum LoaiTinHieu {
  root('ROOT', 'medium'),
  hookFrida('HOOK_FRIDA', 'high'),
  hookXposed('HOOK_XPOSED', 'high'),
  debugger('DEBUGGER_ATTACHED', 'high'),
  emulator('EMULATOR', 'medium'),
  dongGoiLai('APP_REPACKAGED', 'high'),
  giaViTri('MOCK_LOCATION', 'medium'),
  nhanBanApp('CLONE_APP', 'medium'),
  tuDongHoa('AUTOMATION', 'medium'),
  moKhoaBootloader('BOOTLOADER_UNLOCKED', 'low'),
  giaGio('TIME_SPOOFING', 'low'),
  rangBuocThietBi('DEVICE_BINDING', 'low'),
  nguonCaiNgoai('UNOFFICIAL_STORE', 'info'),
  cheDoNhaPhatTrien('DEV_MODE', 'info'),
  adb('ADB_ENABLED', 'info'),
  vpn('VPN', 'info'),
  wifiKhongAnToan('UNSECURE_WIFI', 'info'),
  khongKhoaMan('NO_PASSCODE', 'info'),
  khongPhanCungAnToan('NO_SECURE_HARDWARE', 'info'),
  quayChupMan('SCREEN_CAPTURE', 'info'),
  doiMaThietBi('DEVICE_ID_CHANGED', 'info'),
  loiLamRoi('OBFUSCATION_ISSUE', 'info'),
  thieuKiemTraNative('RASP_NATIVE_MISSING', 'low'),

  /// App rơi vào chế độ an toàn / mất khoá CSDL (A5) - để SOC thấy tỉ lệ
  /// lỗi lưu trữ, không phải tín hiệu tấn công.
  cheDoAnToan('APP_SAFE_MODE', 'info');

  new(this.loai, this.mucDo);

  /// Mã loại sự kiện gửi server (`type`).
  final String loai;

  /// `severity` theo schema server.
  final String mucDo;
}

/// Một tín hiệu đã phát hiện + chi tiết (khoá snake_case, giá trị vô hướng -
/// đúng schema `signals` của server, không PII).
typedef TinHieu = ({LoaiTinHieu loai, Map<String, Object> chiTiet});

/// Kết quả thô của kiểm tra native (Kotlin + NDK) - xem `ThietBiPlugin`.
final class KetQuaNative {
  const new({
    required this.coNative,
    this.bitNative = 0,
    this.jdwp = false,
    this.appDebuggable = false,
    this.testKeys = false,
    this.chungChi = const [],
    this.nguonCai,
  });

  factory tuMap(Map<Object?, Object?>? m) {
    if (m == null) return const KetQuaNative(coNative: false);
    final bit = m['native'];
    final cc = m['chungChi'];
    return KetQuaNative(
      coNative: bit is int && bit >= 0,
      bitNative: bit is int && bit > 0 ? bit : 0,
      jdwp: m['jdwp'] == true,
      appDebuggable: m['appDebuggable'] == true,
      testKeys: m['testKeys'] == true,
      chungChi: cc is List
          ? [
              for (final c in cc)
                if (c is String) c,
            ]
          : const [],
      nguonCai: m['nguonCai'] is String ? m['nguonCai']! as String : null,
    );
  }

  /// Bit của thư viện C++ (`la_ban_kt`).
  static const int bitTracer = 1;
  static const int bitFridaMaps = 1 << 1;
  static const int bitHookMaps = 1 << 2;
  static const int bitSu = 1 << 3;
  static const int bitMagisk = 1 << 4;
  static const int bitFridaCong = 1 << 5;
  static const int bitFridaLuong = 1 << 6;
  static const int bitRoDebuggable = 1 << 7;
  static const int bitQemu = 1 << 8;
  static const int bitXposedLop = 1 << 9;

  /// false: không nạp được thư viện C++ (bị gỡ / sai ABI) - bản thân việc đó
  /// là tín hiệu.
  final bool coNative;
  final int bitNative;
  final bool jdwp;
  final bool appDebuggable;
  final bool testKeys;

  /// SHA-256 (hex thường) các chứng chỉ ký gói đang chạy.
  final List<String> chungChi;

  /// Gói đã cài app (`com.android.vending`...); null = cài tay / adb.
  final String? nguonCai;

  bool _co(int b) => bitNative & b != 0;
}

/// Kết quả native -> danh sách tín hiệu. [chungChiHopLe] rỗng = không kiểm
/// chữ ký gói (bản debug ký khoá debug của máy dev).
List<TinHieu> tinHieuTuNative(
  KetQuaNative k, {
  required List<String> chungChiHopLe,
}) {
  final ds = <TinHieu>[];
  void them(LoaiTinHieu l, Map<String, Object> ct) {
    if (ct.values.any((v) => v == true)) ds.add((loai: l, chiTiet: ct));
  }

  if (!k.coNative) {
    ds.add((loai: LoaiTinHieu.thieuKiemTraNative, chiTiet: const {}));
  }
  them(LoaiTinHieu.debugger, {
    'tracer_pid': k._co(KetQuaNative.bitTracer),
    'jdwp': k.jdwp,
  });
  them(LoaiTinHieu.hookFrida, {
    'maps_agent': k._co(KetQuaNative.bitFridaMaps),
    'port': k._co(KetQuaNative.bitFridaCong),
    'thread': k._co(KetQuaNative.bitFridaLuong),
  });
  them(LoaiTinHieu.hookXposed, {
    'maps_hook': k._co(KetQuaNative.bitHookMaps),
    'xposed_class': k._co(KetQuaNative.bitXposedLop),
  });
  them(LoaiTinHieu.root, {
    'su': k._co(KetQuaNative.bitSu),
    'magisk': k._co(KetQuaNative.bitMagisk),
    'test_keys': k.testKeys,
    'ro_debuggable': k._co(KetQuaNative.bitRoDebuggable),
  });
  them(LoaiTinHieu.emulator, {'qemu': k._co(KetQuaNative.bitQemu)});
  if (chungChiHopLe.isNotEmpty) {
    final sai = k.chungChi.isEmpty || !k.chungChi.every(chungChiHopLe.contains);
    them(LoaiTinHieu.dongGoiLai, {
      'cert_mismatch': sai,
      'debuggable': k.appDebuggable,
    });
  }
  return ds;
}

/// Gộp tín hiệu cùng loại (nhiều nguồn: freeRASP + native) thành một.
Map<LoaiTinHieu, Map<String, Object>> gopTinHieu(Iterable<TinHieu> ds) {
  final kq = <LoaiTinHieu, Map<String, Object>>{};
  for (final t in ds) {
    (kq[t.loai] ??= {}).addAll(t.chiTiet);
  }
  return kq;
}

/// Có nên báo lại một loại không: chưa báo, chi tiết đổi, hoặc lần báo
/// trước đã quá [chuKy]. Server cũng chỉ tính điểm một loại một lần / 24 h -
/// lọc ở đây chỉ để tiết kiệm mạng / pin.
bool canBao({
  required Map<String, Object?>? daBao,
  required String dauVet,
  required int bayGio,
  int chuKy = 24 * 60 * 60 * 1000,
}) {
  if (daBao == null) return true;
  final luc = daBao['luc'];
  if (daBao['dau'] != dauVet || luc is! int) return true;
  return bayGio - luc >= chuKy || bayGio < luc;
}

/// Dấu vết ổn định của chi tiết tín hiệu (khoá đã sắp xếp).
String dauVetTinHieu(Map<String, Object> chiTiet) {
  final k = chiTiet.keys.toList()..sort();
  return k.map((x) => '$x=${chiTiet[x]}').join('&');
}

/// `0.1.0-beta.6` -> `0.1.0` (schema server chỉ nhận x.y.z).
String phienBanLoi(String pb) =>
    RegExp(r'^\d+\.\d+\.\d+').stringMatch(pb) ?? '0.0.0';

/// Sự kiện theo schema `/v1/events` (Spec §7.6b). Chữ ký nằm ở cả lô (header
/// `x-signature` của yêu cầu đã ký) - không ký từng sự kiện.
Map<String, Object?> taoSuKien({
  required String id,
  required LoaiTinHieu loai,
  required Map<String, Object> chiTiet,
  required DateTime luc,
  required ({String phienBan, int build, String? nguonCai}) app,
  required ({String heDieuHanh, String model, bool emulator, String root})
  moiTruong,
}) => {
  'event_id': id,
  'ts': luc.toUtc().toIso8601String(),
  'type': loai.loai,
  'severity': loai.mucDo,
  'signals': {
    for (final e in chiTiet.entries.take(32))
      if (RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(e.key))
        e.key: switch (e.value) {
          final String s when s.length > 128 => s.substring(0, 128),
          final v => v,
        },
  },
  'app': {
    'version': phienBanLoi(app.phienBan),
    'build': app.build < 1 ? 1 : app.build,
    'install_source': switch (app.nguonCai) {
      final String s when s.length > 64 => s.substring(0, 64),
      final s => s,
    },
  },
  'env': {
    'os': 'android',
    'os_ver': _cat(moiTruong.heDieuHanh, 32),
    'model': _cat(moiTruong.model, 64),
    'emulator': moiTruong.emulator,
    'root': moiTruong.root,
  },
};

String _cat(String s, int n) => s.length > n ? s.substring(0, n) : s;

/// Mức rủi ro phía client (Spec §7.3 bảng phản ứng) - suy từ trạng thái do
/// SERVER trả (`/v1/status`), không từ tín hiệu cục bộ.
enum MucRuiRo {
  /// Bình thường, gửi sự kiện nền.
  thap,

  /// Tắt tính năng nhạy cảm (chia sẻ, đồng bộ, quảng cáo thưởng).
  trungBinh,

  /// Chặn tính năng cần API, hiện băng thông báo + mã REF; la bàn offline
  /// vẫn dùng được.
  cao,

  /// Huỷ phiên, xoá token; màn khoá chỉ hiện mã REF (sau khi đã gửi sự kiện).
  nghiemTrong;

  static MucRuiRo tu(TrangThaiThietBi? trangThai, MucTin? mucTin) =>
      switch (trangThai) {
        TrangThaiThietBi.banned => nghiemTrong,
        TrangThaiThietBi.restricted => cao,
        TrangThaiThietBi.suspicious => trungBinh,
        // ID-05: attestation lỗi / chưa xác minh -> hạn chế tính năng nhạy cảm
        // (cùng ngưỡng `duTinCay` với server).
        TrangThaiThietBi.clean when mucTin != null && !mucTin.duTinCay =>
          trungBinh,
        _ => thap,
      };

  bool get choTinhNangNhayCam => this == thap;

  bool get choApi => index < cao.index;

  bool get khoaApp => this == nghiemTrong;
}
