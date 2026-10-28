import 'dart:math' as math;

import 'package:sensors/src/domain/goc_vong.dart';
import 'package:sensors/src/domain/quat.dart';

// Hệ toạ độ (giống Android SensorManager):
//  - MÁY: X sang phải màn hình, Y lên đỉnh máy (dọc tự nhiên), Z ra khỏi
//    mặt kính.
//  - THẾ GIỚI: ENU - X Đông, Y Bắc (từ), Z hướng lên trời.

/// Hướng màn hình so với tư thế tự nhiên (`Display.getRotation`): 0, 90, 180,
/// 270 độ ngược kim đồng hồ.
enum XoayManHinh { r0, r90, r180, r270 }

/// Kết quả tư thế theo khung MÀN HÌNH đang hiển thị.
typedef TuThe = ({
  /// Phương vị từ [0, 360) theo chiều kim đồng hồ, chưa cộng độ lệch từ.
  double phuongVi,

  /// Góc ngóc (độ): mép trên màn hình nâng lên trời là dương.
  double doc,

  /// Góc nghiêng ngang (độ): mép phải màn hình nâng lên là dương.
  double lan,

  /// true khi máy dựng đứng và phương vị lấy theo hướng camera sau (-Z).
  bool theoCamera,
});

/// Trục "lên" và "phải" của màn hình trong toạ độ máy.
({Vec3 len, Vec3 phai}) trucManHinh(XoayManHinh x) => switch (x) {
  // Xoay máy ngược kim đồng hồ 90° thì cạnh phải máy (+X) thành mép trên.
  XoayManHinh.r0 => (len: const Vec3(0, 1, 0), phai: const Vec3(1, 0, 0)),
  XoayManHinh.r90 => (len: const Vec3(1, 0, 0), phai: const Vec3(0, -1, 0)),
  XoayManHinh.r180 => (len: const Vec3(0, -1, 0), phai: const Vec3(-1, 0, 0)),
  XoayManHinh.r270 => (len: const Vec3(-1, 0, 0), phai: const Vec3(0, 1, 0)),
};

/// Phương vị (độ) của vectơ thế giới [v] chiếu lên mặt phẳng ngang.
double phuongViCua(Vec3 v) => chuanHoaDo(radSangDo(math.atan2(v.x, v.y)));

/// Tư thế từ quaternion máy -> ENU. Phương vị là hướng của mép trên màn hình
/// chiếu xuống mặt phẳng ngang (đã bù nghiêng); khi máy dựng gần thẳng đứng
/// hình chiếu đó suy biến nên chuyển sang hướng camera sau - tại điểm chuyển
/// hai hướng trùng nhau nên kim không nhảy.
TuThe tuTheTuQuat(Quat q, {XoayManHinh xoay = XoayManHinh.r0}) {
  final t = trucManHinh(xoay);
  final len = q.xoay(t.len);
  final phai = q.xoay(t.phai);
  final sau = q.xoay(const Vec3(0, 0, -1));
  final ngangLen = math.sqrt(len.x * len.x + len.y * len.y);
  final ngangSau = math.sqrt(sau.x * sau.x + sau.y * sau.y);
  final theoCamera = ngangSau > ngangLen;
  return (
    phuongVi: phuongViCua(theoCamera ? sau : len),
    doc: radSangDo(math.asin(len.z.clamp(-1.0, 1.0))),
    lan: radSangDo(math.asin(phai.z.clamp(-1.0, 1.0))),
    theoCamera: theoCamera,
  );
}

/// Bù nghiêng thuần gia tốc + từ trường (không con quay), giống
/// `SensorManager.getRotationMatrix`: [giaToc] là phản lực trọng trường (máy
/// nằm ngửa đọc +Z), [tu] là từ trường, cùng toạ độ máy. Trả quaternion máy ->
/// ENU, hoặc null khi rơi tự do / từ trường gần song song trọng lực.
Quat? quatTuGiaTocTu(Vec3 giaToc, Vec3 tu) {
  final len = giaToc.donVi;
  if (len == null || giaToc.doDai < 0.1 * 9.81) return null;
  final dong = tu.cheo(len).donVi;
  if (dong == null || tu.cheo(len).doDai < 0.1 * tu.doDai) return null;
  final bac = len.cheo(dong);
  // Các hàng của ma trận (ENU = M * máy) là trục Đông / Bắc / Lên viết theo máy.
  return Quat.tuMaTran([
    dong.x, dong.y, dong.z, //
    bac.x, bac.y, bac.z, //
    len.x, len.y, len.z,
  ]);
}

/// Quaternion từ vectơ quay Android (`TYPE_ROTATION_VECTOR` /
/// `TYPE_GAME_ROTATION_VECTOR`): values = (x, y, z[, w]) - máy -> ENU.
Quat quatTuVectorQuay(double x, double y, double z, [double? w]) {
  final ww = w ?? math.sqrt(math.max(0, 1 - x * x - y * y - z * z));
  return Quat(ww, x, y, z).chuanHoa;
}

/// Độ cao khí áp (m) từ áp suất [hPa] theo khí quyển chuẩn quốc tế, mốc mực
/// nước biển [p0] (mặc định 1013,25 hPa - như `SensorManager.getAltitude`).
double doCaoKhiAp(double hPa, {double p0 = 1013.25}) =>
    44330 * (1 - math.pow(hPa / p0, 1 / 5.255).toDouble());
