import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Quyền vị trí của app (Android: ACCESS_FINE / ACCESS_COARSE_LOCATION).
enum QuyenViTri {
  /// Chưa hỏi lần nào.
  chuaHoi,

  /// Đã từ chối, còn hỏi lại được.
  tuChoi,

  /// Từ chối hẳn ("Không hỏi lại") - chỉ bật được trong Cài đặt hệ thống.
  tuChoiHan,

  /// Chỉ vị trí xấp xỉ (~1-3 km) - đủ cho bắc thực, mặt trời / mặt trăng.
  xapXi,

  /// Vị trí chính xác.
  chinhXac;

  bool get duocPhep => this == xapXi || this == chinhXac;
}

/// Nguồn của một lần đọc vị trí.
enum NguonDocViTri { gps, mang, hopNhat, khac }

/// Một lần đọc vị trí từ nền tảng. Đại lượng máy không cung cấp là null.
@immutable
final class DocViTri {
  const new({
    required this.viDo,
    required this.kinhDo,
    required this.luc,
    this.doCaoElip,
    this.doCaoMucBien,
    this.doChinhXacNgang,
    this.doChinhXacDung,
    this.tocDo,
    this.huongDi,
    this.nguon = NguonDocViTri.khac,
    this.gia = false,
  });

  final double viDo;
  final double kinhDo;
  final DateTime luc;

  /// Nền tảng đánh dấu vị trí giả (`Location.isMock`: nhà cung cấp thử / app
  /// giả vị trí). Chỉ để báo tín hiệu `MOCK_LOCATION` - server quyết định.
  final bool gia;

  /// Độ cao trên elipxoit WGS84 (m) - `Location.getAltitude`.
  final double? doCaoElip;

  /// Độ cao trên mực biển do nền tảng tính (Android 14+), m.
  final double? doCaoMucBien;

  /// Bán kính sai số ngang 68% (m).
  final double? doChinhXacNgang;
  final double? doChinhXacDung;

  /// m/s.
  final double? tocDo;

  /// Hướng di chuyển (độ, bắc thực).
  final double? huongDi;
  final NguonDocViTri nguon;

  @override
  bool operator ==(Object other) =>
      other is DocViTri &&
      other.viDo == viDo &&
      other.kinhDo == kinhDo &&
      other.luc == luc &&
      other.doCaoElip == doCaoElip &&
      other.doChinhXacNgang == doChinhXacNgang;

  @override
  int get hashCode => Object.hash(viDo, kinhDo, luc, doCaoElip);
}

double? _soHuuHan(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

/// Giải mã sự kiện nền tảng: danh sách 10 số
/// [vĩ, kinh, cao elip, ±ngang, ±dọc, tốc độ, hướng, ms epoch, cao mực biển,
/// nguồn]; NaN = không có.
DocViTri? giaiMaDocViTri(Object? e) {
  if (e is! List || e.length < 10) return null;
  final vi = _soHuuHan(e[0]);
  final kinh = _soHuuHan(e[1]);
  final ms = _soHuuHan(e[7]);
  if (vi == null || kinh == null || ms == null) return null;
  if (vi.abs() > 90 || kinh.abs() > 180) return null;
  final nguon = _soHuuHan(e[9])?.toInt() ?? 3;
  return DocViTri(
    viDo: vi,
    kinhDo: kinh,
    luc: DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true),
    doCaoElip: _soHuuHan(e[2]),
    doChinhXacNgang: _soHuuHan(e[3]),
    doChinhXacDung: _soHuuHan(e[4]),
    tocDo: _soHuuHan(e[5]),
    huongDi: _soHuuHan(e[6]),
    doCaoMucBien: _soHuuHan(e[8]),
    nguon: NguonDocViTri.values[nguon.clamp(0, 3)],
    gia: e.length > 10 && _soHuuHan(e[10]) == 1,
  );
}

QuyenViTri quyenTuChuoi(String? s) => QuyenViTri.values.firstWhere(
  (q) => q.name == s,
  orElse: () => QuyenViTri.chuaHoi,
);

/// Vị trí lưu bền làm tròn 0,1° (~11 km): đủ tính độ lệch từ (đổi < 0,1° /
/// 10 km) và mặt trời / mặt trăng, không lưu vị trí chính xác của người
/// dùng xuống đĩa.
({double viDo, double kinhDo}) lamTronLuu(double viDo, double kinhDo) =>
    (viDo: (viDo * 10).round() / 10, kinhDo: (kinhDo * 10).round() / 10);

/// Có nên tra lại địa giới / ghi lại vị trí lưu: đã dời > [nguongM] mét.
bool daDoiCho(
  ({double viDo, double kinhDo})? cu,
  double viDo,
  double kinhDo, {
  double nguongM = 50,
}) {
  if (cu == null) return true;
  // Xấp xỉ phẳng - đủ cho ngưỡng vài chục mét.
  const mPerDo = 111320.0;
  final dy = (viDo - cu.viDo) * mPerDo;
  final dx = (kinhDo - cu.kinhDo) * mPerDo * math.cos(viDo * math.pi / 180);
  return dx * dx + dy * dy > nguongM * nguongM;
}
