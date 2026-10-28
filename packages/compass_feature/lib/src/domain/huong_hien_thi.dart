import 'package:sensors/sensors.dart';

/// Hướng đem lên mặt la bàn sau khi chọn tham chiếu bắc.
final class HuongHienThi {
  const new({
    required this.phuongVi,
    required this.bacThuc,
    required this.thieuViTri,
    this.doLech,
    this.moHinhCu = false,
  });

  /// Phương vị [0, 360) theo tham chiếu [bacThuc].
  final double phuongVi;

  /// true: theo bắc thực (đã cộng độ lệch từ); false: bắc từ.
  final bool bacThuc;

  /// Người dùng chọn bắc thực nhưng chưa có vị trí -> đang hiện bắc từ.
  final bool thieuViTri;

  /// Độ lệch từ WMM tại vị trí hiện tại (độ, dương = đông), null khi chưa
  /// có vị trí.
  final double? doLech;

  /// Mô hình WMM đã quá hạn hiệu lực (cần cập nhật hệ số).
  final bool moHinhCu;

  /// Số độ làm tròn 0,1° trong [0; 359,9] (359,96 -> 0,0 chứ không 360,0).
  double get soDo01 => ((phuongVi * 10).round() % 3600) / 10;
}

/// Chuyển phương vị từ [phuongViTu] sang hướng hiển thị. [tuTruong] là kết
/// quả WMM tại vị trí hiện tại (null = chưa có vị trí).
HuongHienThi tinhHuongHienThi(
  double phuongViTu, {
  required bool muonBacThuc,
  TuTruongDiaCau? tuTruong,
}) {
  final doLech = tuTruong?.doLech;
  final dungBacThuc = muonBacThuc && doLech != null && doLech.isFinite;
  return HuongHienThi(
    phuongVi: chuanHoaDo(dungBacThuc ? phuongViTu + doLech : phuongViTu),
    bacThuc: dungBacThuc,
    thieuViTri: muonBacThuc && doLech == null,
    doLech: doLech,
    moHinhCu: tuTruong?.ngoaiHan ?? false,
  );
}
