import 'dart:convert';

import 'package:network/src/domain/chung_chi.dart';
import 'package:network/src/domain/ed25519.dart';
import 'package:network/src/du_lieu/goc_tin_cay.g.dart';

/// Remote Config đã kiểm chữ ký (SEC-NET). Sinh bởi
/// `tools/cau-hinh/ky-cau-hinh.mjs ky-app` - khớp `taoNoiDungApp`.
final class CauHinhTuXa {
  const new({
    required this.phatHanh,
    required this.het,
    required this.toiThieu,
    required this.khuyenNghi,
    required this.tat,
    required this.pin,
    required this.gocThem,
  });

  /// Thời điểm ký (ms) - tăng dần; gói cũ hơn gói đang giữ bị từ chối (chống
  /// phát lại gói cũ để hạ pin / bỏ cập nhật bắt buộc).
  final int phatHanh;

  /// Hết hạn (ms): quá hạn thì app quay về mặc định đóng gói.
  final int het;

  /// Mã build tối thiểu còn được dùng (thấp hơn -> bắt buộc cập nhật).
  final int toiThieu;

  /// Mã build khuyến nghị (thấp hơn -> gợi ý cập nhật, bỏ qua được).
  final int khuyenNghi;

  /// Tính năng tắt từ xa (kill-switch): `ban-do`, `ar`, `chia-se`...
  final Set<String> tat;

  /// Pin SPKI SHA-256 (base64) của CA gốc được tin, >= 2.
  final List<String> pin;

  /// PEM CA gốc mới (chưa đóng gói trong app) - mỗi cái phải có pin ở [pin].
  final List<String> gocThem;

  /// PEM các CA được tin theo cấu hình này: CA đóng gói có pin được bật +
  /// [gocThem].
  List<String> get gocHieuLuc => [
    for (final g in gocTinCay)
      if (pin.contains(g.pin)) g.pem,
    ...gocThem,
  ];
}

/// Mọi CA đóng gói (khi chưa có / hết hạn Remote Config).
List<String> get gocMacDinh => [for (final g in gocTinCay) g.pem];

/// Kết quả đọc gói Remote Config.
sealed class KetQuaGoi {
  const new();
}

final class GoiHopLe extends KetQuaGoi {
  const new(this.cauHinh);

  final CauHinhTuXa cauHinh;
}

/// Gói bị từ chối: `dang` (hình dạng), `kid`, `chu-ky`, `het-han`, `cu-hon`,
/// `noi-dung` (thiếu trường / pin không đủ 2 CA dùng được).
final class GoiBiTuChoi extends KetQuaGoi {
  const new(this.lyDo);

  final String lyDo;
}

List<int>? _b64url(Object? s) {
  if (s is! String || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(s)) return null;
  try {
    return base64Url.decode(base64Url.normalize(s));
  } on FormatException {
    return null;
  }
}

/// Đọc + kiểm gói `{kid, duLieu, chuKy}`: chữ ký Ed25519 trên đúng byte
/// `duLieu` bằng khoá công khai theo kid trong [khoa] (base64url 32 byte),
/// còn hạn ở [bayGio], không cũ hơn [phatHanhDangGiu].
KetQuaGoi docGoiCauHinh(
  String raw, {
  required Map<String, String> khoa,
  required int bayGio,
  int? phatHanhDangGiu,
}) {
  final Object? goi;
  try {
    goi = jsonDecode(raw);
  } on FormatException {
    return const GoiBiTuChoi('dang');
  }
  if (goi is! Map<String, Object?>) return const GoiBiTuChoi('dang');
  final kid = goi['kid'];
  final duLieu = _b64url(goi['duLieu']);
  final chuKy = _b64url(goi['chuKy']);
  if (kid is! String || duLieu == null || chuKy == null) {
    return const GoiBiTuChoi('dang');
  }
  final khoaCongKhai = _b64url(khoa[kid]);
  if (khoaCongKhai == null) return const GoiBiTuChoi('kid');
  if (!kiemEd25519(khoaCongKhai, duLieu, chuKy)) {
    return const GoiBiTuChoi('chu-ky');
  }
  final ch = _noiDung(duLieu);
  if (ch == null) return const GoiBiTuChoi('noi-dung');
  if (ch.het <= bayGio) return const GoiBiTuChoi('het-han');
  if (phatHanhDangGiu != null && ch.phatHanh < phatHanhDangGiu) {
    return const GoiBiTuChoi('cu-hon');
  }
  return GoiHopLe(ch);
}

CauHinhTuXa? _noiDung(List<int> duLieu) {
  final Object? j;
  try {
    j = jsonDecode(utf8.decode(duLieu));
  } on FormatException {
    return null;
  }
  if (j is! Map<String, Object?> || j['v'] != 1) return null;
  final capNhat = j['capNhat'];
  final tat = j['tat'];
  final pin = j['pin'];
  final gocThem = j['gocThem'] ?? const <Object?>[];
  if (j['phatHanh'] case final int phatHanh
      when capNhat is Map<String, Object?> &&
          tat is List<Object?> &&
          pin is List<Object?> &&
          gocThem is List<Object?>) {
    final het = j['het'];
    final toiThieu = capNhat['toiThieu'];
    final khuyenNghi = capNhat['khuyenNghi'];
    if (het is! int || toiThieu is! int || khuyenNghi is! int) return null;
    final dsPin = pin.whereType<String>().toList();
    final dsGoc = gocThem.whereType<String>().toList();
    // Mỗi CA thêm phải có pin trong danh sách (khớp kiểm ở công cụ ký).
    if (dsGoc.any((p) => !dsPin.contains(pinCuaPem(p)))) return null;
    final ch = CauHinhTuXa(
      phatHanh: phatHanh,
      het: het,
      toiThieu: toiThieu,
      khuyenNghi: khuyenNghi,
      tat: tat.whereType<String>().toSet(),
      pin: dsPin,
      gocThem: dsGoc,
    );
    // >= 2 CA thật sự dùng được (1 đang dùng + 1 dự phòng) - không thì giữ
    // cấu hình cũ, tránh tự khoá app khỏi API.
    if (dsPin.toSet().length < 2 || ch.gocHieuLuc.length < 2) return null;
    return ch;
  }
  return null;
}
