import 'package:meta/meta.dart';

/// Vị trí địa lý WGS84 (độ; độ cao mét trên elipxoit). Nguồn: GPS (A4) hoặc
/// vị trí lưu gần nhất - dùng tính độ lệch từ WMM, mặt trời / mặt trăng.
@immutable
final class ViTriDiaLy {
  const new({required this.viDo, required this.kinhDo, this.doCaoM = 0});

  final double viDo;
  final double kinhDo;
  final double doCaoM;

  @override
  bool operator ==(Object other) =>
      other is ViTriDiaLy &&
      other.viDo == viDo &&
      other.kinhDo == kinhDo &&
      other.doCaoM == doCaoM;

  @override
  int get hashCode => Object.hash(viDo, kinhDo, doCaoM);
}
