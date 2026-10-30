import 'dart:math';

import 'package:waypoint_feature/src/domain/trac_dia.dart';

/// Bán kính "đã tới" tối thiểu (m): GPS điện thoại sai số ~5-15 m.
const banKinhToiM = 15.0;

/// Trạng thái dẫn đường tới một điểm.
typedef DanDuong = ({
  double khoangCachM,

  /// Phương vị tới đích, bắc thực, [0, 360).
  double phuongVi,

  /// Góc phải quay so với hướng máy đang chỉ (-180, 180], dương = phải.
  /// null khi không có la bàn.
  double? gocQuay,

  bool daToi,
});

/// Tính dẫn đường từ vị trí hiện tại tới đích. [huongTu] là phương vị BẮC
/// TỪ của máy (null = không có la bàn); [doLech] độ lệch từ WMM tại chỗ
/// (dương = đông) để đổi sang bắc thực cùng hệ với phương vị trắc địa.
DanDuong tinhDanDuong({
  required double viDo,
  required double kinhDo,
  required double dichViDo,
  required double dichKinhDo,
  double? saiSoM,
  double? huongTu,
  double doLech = 0,
}) {
  final t = tracDia(viDo, kinhDo, dichViDo, dichKinhDo);
  final ban = max(banKinhToiM, saiSoM ?? 0);
  return (
    khoangCachM: t.khoangCachM,
    phuongVi: t.phuongViDau,
    gocQuay: huongTu == null
        ? null
        : gocLech(chuanHoa360(huongTu + doLech), t.phuongViDau),
    daToi: t.khoangCachM <= ban,
  );
}
