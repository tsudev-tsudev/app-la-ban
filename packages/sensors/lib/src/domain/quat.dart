// Công thức quaternion / ma trận viết gọn theo dạng sách giáo khoa.
// ignore_for_file: avoid_multiple_declarations_per_line

import 'dart:math' as math;

/// Vectơ 3 chiều bất biến.
final class Vec3 {
  const new(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  final double x;
  final double y;
  final double z;

  double get doDai => math.sqrt(x * x + y * y + z * z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double cham(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cheo(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  /// Vectơ đơn vị; null nếu gần bằng 0.
  Vec3? get donVi {
    final d = doDai;
    return d < 1e-9 ? null : this * (1 / d);
  }

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// Quaternion đơn vị (w, x, y, z) mô tả phép quay THÂN MÁY -> THẾ GIỚI:
/// `xoay(v)` đổi vectơ toạ độ máy sang toạ độ thế giới.
final class Quat {
  const new(this.w, this.x, this.y, this.z);

  /// Quay góc [rad] quanh trục [truc] (quy tắc bàn tay phải).
  factory quanhTruc(Vec3 truc, double rad) {
    final u = truc.donVi ?? const Vec3(0, 0, 1);
    final s = math.sin(rad / 2);
    return Quat(math.cos(rad / 2), u.x * s, u.y * s, u.z * s);
  }

  /// Từ ma trận quay 3x3 hàng-trước [m] (9 phần tử, thế giới = M * máy).
  factory tuMaTran(List<double> m) {
    final vet = m[0] + m[4] + m[8];
    double w, x, y, z;
    if (vet > 0) {
      final s = math.sqrt(vet + 1) * 2;
      w = s / 4;
      x = (m[7] - m[5]) / s;
      y = (m[2] - m[6]) / s;
      z = (m[3] - m[1]) / s;
    } else if (m[0] > m[4] && m[0] > m[8]) {
      final s = math.sqrt(1 + m[0] - m[4] - m[8]) * 2;
      w = (m[7] - m[5]) / s;
      x = s / 4;
      y = (m[1] + m[3]) / s;
      z = (m[2] + m[6]) / s;
    } else if (m[4] > m[8]) {
      final s = math.sqrt(1 + m[4] - m[0] - m[8]) * 2;
      w = (m[2] - m[6]) / s;
      x = (m[1] + m[3]) / s;
      y = s / 4;
      z = (m[5] + m[7]) / s;
    } else {
      final s = math.sqrt(1 + m[8] - m[0] - m[4]) * 2;
      w = (m[3] - m[1]) / s;
      x = (m[2] + m[6]) / s;
      y = (m[5] + m[7]) / s;
      z = s / 4;
    }
    return Quat(w, x, y, z).chuanHoa;
  }

  static const donVi = Quat(1, 0, 0, 0);

  final double w;
  final double x;
  final double y;
  final double z;

  double get chuan => math.sqrt(w * w + x * x + y * y + z * z);

  Quat get chuanHoa {
    final n = chuan;
    return n < 1e-12 ? donVi : Quat(w / n, x / n, y / n, z / n);
  }

  Quat get lienHop => Quat(w, -x, -y, -z);

  /// Tích Hamilton `this ⊗ o` (áp [o] trước, rồi `this`).
  Quat operator *(Quat o) => Quat(
    w * o.w - x * o.x - y * o.y - z * o.z,
    w * o.x + x * o.w + y * o.z - z * o.y,
    w * o.y - x * o.z + y * o.w + z * o.x,
    w * o.z + x * o.y - y * o.x + z * o.w,
  );

  /// Ma trận quay hàng-trước (thế giới = M * máy).
  List<double> get maTran {
    final xx = x * x, yy = y * y, zz = z * z;
    final xy = x * y, xz = x * z, yz = y * z;
    final wx = w * x, wy = w * y, wz = w * z;
    return [
      1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy), //
      2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx), //
      2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy),
    ];
  }

  /// Đổi vectơ toạ độ máy sang toạ độ thế giới.
  Vec3 xoay(Vec3 v) {
    final m = maTran;
    return Vec3(
      m[0] * v.x + m[1] * v.y + m[2] * v.z,
      m[3] * v.x + m[4] * v.y + m[5] * v.z,
      m[6] * v.x + m[7] * v.y + m[8] * v.z,
    );
  }

  /// Đổi vectơ toạ độ thế giới sang toạ độ máy.
  Vec3 xoayNguoc(Vec3 v) => lienHop.xoay(v);

  @override
  String toString() => 'Quat($w, $x, $y, $z)';
}
