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
