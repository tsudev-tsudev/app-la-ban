/// Mức tin cậy server xếp cho thiết bị (devices.attestation_level).
enum MucTin {
  strong,
  device,
  basic,
  failed,
  unverified;

  static MucTin tuChuoi(Object? s) => MucTin.values.firstWhere(
    (m) => m.name == s,
    orElse: () => MucTin.unverified,
  );

  /// Đủ cho tính năng nhạy cảm (khớp duTinCay ở server - server vẫn quyết).
  bool get duTinCay => this == strong || this == device;
}

/// Phiên thiết bị: access token JWT 15 phút + refresh token xoay vòng.
final class PhienThietBi {
  const new({
    required this.thietBiId,
    required this.accessToken,
    required this.hetHan,
    required this.refreshToken,
    required this.mucTin,
  });

  /// Từ JSON đã lưu / phản hồi server; thiếu trường -> null.
  static PhienThietBi? tuJson(Map<String, Object?>? j, {String? thietBiId}) {
    final p = j?['phien'];
    final nguon = p is Map<String, Object?> ? p : j;
    final id = thietBiId ?? j?['thietBiId'];
    final at = nguon?['accessToken'];
    final het = nguon?['hetHan'];
    final rt = nguon?['refreshToken'];
    if (id is! String || at is! String || het is! int || rt is! String) {
      return null;
    }
    return PhienThietBi(
      thietBiId: id,
      accessToken: at,
      hetHan: het,
      refreshToken: rt,
      mucTin: MucTin.tuChuoi(j?['mucTin']),
    );
  }

  final String thietBiId;
  final String accessToken;

  /// Hạn access token (ms Unix).
  final int hetHan;
  final String refreshToken;
  final MucTin mucTin;

  /// Làm mới trước khi hết hạn [truoc] để không gửi token sắp chết.
  bool canLamMoi(int bayGio, {int truoc = 60 * 1000}) =>
      hetHan - truoc <= bayGio;

  Map<String, Object?> toJson() => {
    'thietBiId': thietBiId,
    'mucTin': mucTin.name,
    'phien': {
      'accessToken': accessToken,
      'hetHan': hetHan,
      'refreshToken': refreshToken,
    },
  };
}

/// Phản hồi lỗi của /v1/session/refresh -> việc app làm tiếp.
enum SauLamMoi {
  /// Phiên chết hẳn (thu hồi, hết hạn, sai) -> đăng ký lại bằng khoá.
  dangKyLai,

  /// Đang xoay ở yêu cầu khác / tạm thời -> giữ phiên, thử lại sau.
  thuLaiSau,

  /// Thiết bị bị cấm -> dừng, không thử nữa.
  biCam;

  static SauLamMoi tuPhanHoi(int status, String? ma) => switch ((status, ma)) {
    (403, 'thiet-bi-bi-cam') => biCam,
    (401, _) => dangKyLai,
    _ => thuLaiSau,
  };
}

/// Lịch thử lại đăng ký / làm mới khi lỗi (mạng chập chờn lúc mở app, Wi-Fi
/// đang chuyển...). Hết lượt -> chờ lần app quay lại foreground.
abstract final class LichThuLai {
  static const khoang = [
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  /// Chờ bao lâu trước lần thử thứ [lan] (đếm từ 0); null = thôi.
  /// Thiết bị bị cấm thì không thử lại.
  static Duration? cho(int lan, String maLoi) {
    if (maLoi == 'dinhDanh.biCam' || lan < 0 || lan >= khoang.length) {
      return null;
    }
    return khoang[lan];
  }
}

/// Trạng thái thiết bị từ `/v1/status` (server quyết; S4 dùng để hiện màn
/// khoá theo Risk Level).
enum TrangThaiThietBi {
  clean,
  suspicious,
  restricted,
  banned;

  static TrangThaiThietBi tuChuoi(Object? s) => TrangThaiThietBi.values
      .firstWhere((m) => m.name == s, orElse: () => TrangThaiThietBi.clean);
}

/// Phản hồi `/v1/status`: trạng thái, mức tin cậy, mã REF (khi bị hạn chế /
/// cấm) và bản APK mới nhất (bản tải ngoài Play chưa tự cập nhật được).
final class TinhTrangThietBi {
  const new({
    required this.trangThai,
    required this.mucTin,
    this.ref,
    this.banMoi,
    this.cheDoPhatTrien = false,
  });

  /// Server từ chối phiên vì thiết bị bị cấm: trạng thái `banned` + mã REF
  /// tính từ id thiết bị theo đúng dạng Worker (`maRef`, `thuan/kenh.ts`).
  factory biCam(PhienThietBi p) => TinhTrangThietBi(
    trangThai: TrangThaiThietBi.banned,
    mucTin: p.mucTin,
    ref: maRefThietBi(p.thietBiId),
  );

  final TrangThaiThietBi trangThai;
  final MucTin mucTin;
  final String? ref;
  final ({String phienBan, int maPhienBan})? banMoi;

  /// S11 (Q57): Worker đang chặn vì Developer options / ADB bật.
  final bool cheDoPhatTrien;

  /// Bản sao với [cheDoPhatTrien] mới (app vừa thấy người dùng tắt - không
  /// giữ màn chặn theo phản hồi cũ trong lúc chờ `/v1/status` mới).
  TinhTrangThietBi voiPhatTrien({required bool chan}) => TinhTrangThietBi(
    trangThai: trangThai,
    mucTin: mucTin,
    ref: ref,
    banMoi: banMoi,
    cheDoPhatTrien: chan,
  );

  /// Thân JSON -> tình trạng; sai dạng -> null.
  static TinhTrangThietBi? tuJson(Map<String, Object?>? j) {
    if (j == null || j['trangThai'] is! String) return null;
    final b = j['banMoi'];
    final ref = j['ref'];
    return TinhTrangThietBi(
      trangThai: TrangThaiThietBi.tuChuoi(j['trangThai']),
      mucTin: MucTin.tuChuoi(j['mucTin']),
      ref: ref is String ? ref : null,
      banMoi:
          b is Map<String, Object?> &&
              b['phienBan'] is String &&
              b['maPhienBan'] is int
          ? (
              phienBan: b['phienBan']! as String,
              maPhienBan: b['maPhienBan']! as int,
            )
          : null,
      cheDoPhatTrien: j['cheDoPhatTrien'] == true,
    );
  }
}

/// Mã REF hiện trên màn khoá / dùng khiếu nại: 10 ký tự cuối của id thiết bị
/// (ULID 26 ký tự Crockford) dạng `REF-XXXXX-XXXXX` - cùng công thức `maRef`
/// của Worker. Id sai dạng -> null (màn khoá không hiện REF).
String? maRefThietBi(String thietBiId) {
  if (!RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(thietBiId)) return null;
  final d = thietBiId.substring(16);
  return 'REF-${d.substring(0, 5)}-${d.substring(5)}';
}
