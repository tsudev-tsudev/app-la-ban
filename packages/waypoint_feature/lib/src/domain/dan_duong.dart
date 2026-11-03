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
/// [daToiTruoc]: kết quả lần trước - đã tới thì chỉ rời trạng thái khi ra xa
/// hơn 1,5 lần bán kính + 5 m (trễ hai ngưỡng, GPS nhiễu không làm màn đổi
/// qua lại giữa "Đã tới" và mũi tên).
DanDuong tinhDanDuong({
  required double viDo,
  required double kinhDo,
  required double dichViDo,
  required double dichKinhDo,
  double? saiSoM,
  double? huongTu,
  double doLech = 0,
  bool daToiTruoc = false,
}) {
  final t = tracDia(viDo, kinhDo, dichViDo, dichKinhDo);
  final ban = max(banKinhToiM, saiSoM ?? 0);
  return (
    khoangCachM: t.khoangCachM,
    phuongVi: t.phuongViDau,
    gocQuay: huongTu == null
        ? null
        : gocLech(chuanHoa360(huongTu + doLech), t.phuongViDau),
    daToi: t.khoangCachM <= (daToiTruoc ? ban * 1.5 + 5 : ban),
  );
}

/// Góc quay coi như "đi thẳng" (độ): vào khi |góc| <= [gocVaoThang], ra khi
/// > [gocRaThang] - trễ hai ngưỡng để chỉ dẫn không đổi qua lại liên tục.
const gocVaoThang = 10.0;
const gocRaThang = 15.0;

/// Chỉ dẫn "đi thẳng" có trễ; [truoc] là kết quả lần trước.
bool diThang(double gocQuay, {required bool truoc}) =>
    gocQuay.abs() <= (truoc ? gocRaThang : gocVaoThang);
