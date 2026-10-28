// Giữ khai báo gọn như mã tham chiếu của bài báo để dễ đối chiếu công thức.
// ignore_for_file: avoid_multiple_declarations_per_line

import 'dart:math' as math;

import 'package:sensors/src/domain/quat.dart';

/// Lọc Madgwick (MARG: con quay + gia tốc + từ trường), theo bài báo gốc
/// "An efficient orientation filter for inertial and inertial/magnetic sensor
/// arrays" (S. Madgwick, 2010).
///
/// Bên trong dùng khung thế giới NWU (X Bắc, Y Tây, Z Lên) như bài báo - từ
/// trường tham chiếu dạng (bx, 0, bz); [tuThe] trả quaternion máy -> ENU để
/// khớp phần còn lại của gói.
final class Madgwick {
  /// [beta]: hệ số bước gradient (rad/s) - lớn hội tụ nhanh nhưng rung hơn.
  /// [betaKhoiDong] dùng trong [thoiGianKhoiDong] giây đầu để bám nhanh.
  new({this.beta = 0.08, this.betaKhoiDong = 1.5, this.thoiGianKhoiDong = 1.5});

  final double beta;
  final double betaKhoiDong;
  final double thoiGianKhoiDong;

  // Quaternion máy -> NWU.
  double _q0 = 1, _q1 = 0, _q2 = 0, _q3 = 0;
  var _daChay = 0.0;

  // ENU = Rz(+90°) * NWU.
  static final _nwuSangEnu = Quat.quanhTruc(const Vec3(0, 0, 1), math.pi / 2);

  /// Quaternion máy -> ENU hiện tại.
  Quat get tuThe => _nwuSangEnu * Quat(_q0, _q1, _q2, _q3);

  /// Đặt lại về tư thế [q] (máy -> ENU), ví dụ từ bù nghiêng gia tốc + từ.
  void datLai(Quat q) {
    final n = (_nwuSangEnu.lienHop * q).chuanHoa;
    _q0 = n.w;
    _q1 = n.x;
    _q2 = n.y;
    _q3 = n.z;
    _daChay = 0;
  }

  double get _betaHienTai => _daChay < thoiGianKhoiDong ? betaKhoiDong : beta;

  /// Một bước với con quay [g] (rad/s), gia tốc [a] (bất kỳ đơn vị), từ
  /// trường [m] (bất kỳ đơn vị), sau [dt] giây. [m] null -> chỉ dùng
  /// gia tốc (khi từ trường bị nhiễu, tránh kéo lệch hướng).
  void capNhat(Vec3 g, Vec3 a, Vec3? m, double dt) {
    if (m == null || m.doDai < 1e-9) {
      _capNhatImu(g, a, dt);
      return;
    }
    final q0 = _q0, q1 = _q1, q2 = _q2, q3 = _q3;
    var qd0 = 0.5 * (-q1 * g.x - q2 * g.y - q3 * g.z);
    var qd1 = 0.5 * (q0 * g.x + q2 * g.z - q3 * g.y);
    var qd2 = 0.5 * (q0 * g.y - q1 * g.z + q3 * g.x);
    var qd3 = 0.5 * (q0 * g.z + q1 * g.y - q2 * g.x);

    final an = a.donVi;
    final mn = m.donVi;
    if (an != null && mn != null) {
      final ax = an.x, ay = an.y, az = an.z;
      final mx = mn.x, my = mn.y, mz = mn.z;
      final t2q0mx = 2 * q0 * mx, t2q0my = 2 * q0 * my, t2q0mz = 2 * q0 * mz;
      final t2q1mx = 2 * q1 * mx;
      final t2q0 = 2 * q0, t2q1 = 2 * q1, t2q2 = 2 * q2, t2q3 = 2 * q3;
      final t2q0q2 = 2 * q0 * q2, t2q2q3 = 2 * q2 * q3;
      final q0q0 = q0 * q0, q0q1 = q0 * q1, q0q2 = q0 * q2, q0q3 = q0 * q3;
      final q1q1 = q1 * q1, q1q2 = q1 * q2, q1q3 = q1 * q3;
      final q2q2 = q2 * q2, q2q3 = q2 * q3, q3q3 = q3 * q3;

      // Từ trường đo được quay sang khung thế giới -> tham chiếu (bx, 0, bz).
      final hx =
          mx * q0q0 -
          t2q0my * q3 +
          t2q0mz * q2 +
          mx * q1q1 +
          t2q1 * my * q2 +
          t2q1 * mz * q3 -
          mx * q2q2 -
          mx * q3q3;
      final hy =
          t2q0mx * q3 +
          my * q0q0 -
          t2q0mz * q1 +
          t2q1mx * q2 -
          my * q1q1 +
          my * q2q2 +
          t2q2 * mz * q3 -
          my * q3q3;
      final t2bx = math.sqrt(hx * hx + hy * hy);
      final t2bz =
          -t2q0mx * q2 +
          t2q0my * q1 +
          mz * q0q0 +
          t2q1mx * q3 -
          mz * q1q1 +
          t2q2 * my * q3 -
          mz * q2q2 +
          mz * q3q3;
      final t4bx = 2 * t2bx, t4bz = 2 * t2bz;

      // Sai lệch giữa hướng ước lượng và đo được của trọng lực / từ trường.
      final fg1 = 2 * q1q3 - t2q0q2 - ax;
      final fg2 = 2 * q0q1 + t2q2q3 - ay;
      final fg3 = 1 - 2 * q1q1 - 2 * q2q2 - az;
      final fb1 = t2bx * (0.5 - q2q2 - q3q3) + t2bz * (q1q3 - q0q2) - mx;
      final fb2 = t2bx * (q1q2 - q0q3) + t2bz * (q0q1 + q2q3) - my;
      final fb3 = t2bx * (q0q2 + q1q3) + t2bz * (0.5 - q1q1 - q2q2) - mz;

      var s0 =
          -t2q2 * fg1 +
          t2q1 * fg2 -
          t2bz * q2 * fb1 +
          (-t2bx * q3 + t2bz * q1) * fb2 +
          t2bx * q2 * fb3;
      var s1 =
          t2q3 * fg1 +
          t2q0 * fg2 -
          4 * q1 * fg3 +
          t2bz * q3 * fb1 +
          (t2bx * q2 + t2bz * q0) * fb2 +
          (t2bx * q3 - t4bz * q1) * fb3;
      var s2 =
          -t2q0 * fg1 +
          t2q3 * fg2 -
          4 * q2 * fg3 +
          (-t4bx * q2 - t2bz * q0) * fb1 +
          (t2bx * q1 + t2bz * q3) * fb2 +
          (t2bx * q0 - t4bz * q2) * fb3;
      var s3 =
          t2q1 * fg1 +
          t2q2 * fg2 +
          (-t4bx * q3 + t2bz * q1) * fb1 +
          (-t2bx * q0 + t2bz * q2) * fb2 +
          t2bx * q1 * fb3;
      final n = math.sqrt(s0 * s0 + s1 * s1 + s2 * s2 + s3 * s3);
      if (n > 1e-12) {
        final b = _betaHienTai / n;
        s0 *= b;
        s1 *= b;
        s2 *= b;
        s3 *= b;
        qd0 -= s0;
        qd1 -= s1;
        qd2 -= s2;
        qd3 -= s3;
      }
    }
    _tichPhan(qd0, qd1, qd2, qd3, dt);
  }

  void _capNhatImu(Vec3 g, Vec3 a, double dt) {
    final q0 = _q0, q1 = _q1, q2 = _q2, q3 = _q3;
    var qd0 = 0.5 * (-q1 * g.x - q2 * g.y - q3 * g.z);
    var qd1 = 0.5 * (q0 * g.x + q2 * g.z - q3 * g.y);
    var qd2 = 0.5 * (q0 * g.y - q1 * g.z + q3 * g.x);
    var qd3 = 0.5 * (q0 * g.z + q1 * g.y - q2 * g.x);
    final an = a.donVi;
    if (an != null) {
      final ax = an.x, ay = an.y, az = an.z;
      final q0q0 = q0 * q0, q1q1 = q1 * q1, q2q2 = q2 * q2, q3q3 = q3 * q3;
      var s0 = 4 * q0 * q2q2 + 2 * q2 * ax + 4 * q0 * q1q1 - 2 * q1 * ay;
      var s1 =
          4 * q1 * q3q3 -
          2 * q3 * ax +
          4 * q0q0 * q1 -
          2 * q0 * ay -
          4 * q1 +
          8 * q1 * q1q1 +
          8 * q1 * q2q2 +
          4 * q1 * az;
      var s2 =
          4 * q0q0 * q2 +
          2 * q0 * ax +
          4 * q2 * q3q3 -
          2 * q3 * ay -
          4 * q2 +
          8 * q2 * q1q1 +
          8 * q2 * q2q2 +
          4 * q2 * az;
      var s3 = 4 * q1q1 * q3 - 2 * q1 * ax + 4 * q2q2 * q3 - 2 * q2 * ay;
      final n = math.sqrt(s0 * s0 + s1 * s1 + s2 * s2 + s3 * s3);
      if (n > 1e-12) {
        final b = _betaHienTai / n;
        s0 *= b;
        s1 *= b;
        s2 *= b;
        s3 *= b;
        qd0 -= s0;
        qd1 -= s1;
        qd2 -= s2;
        qd3 -= s3;
      }
    }
    _tichPhan(qd0, qd1, qd2, qd3, dt);
  }

  void _tichPhan(double d0, double d1, double d2, double d3, double dt) {
    final q = Quat(
      _q0 + d0 * dt,
      _q1 + d1 * dt,
      _q2 + d2 * dt,
      _q3 + d3 * dt,
    ).chuanHoa;
    _q0 = q.w;
    _q1 = q.x;
    _q2 = q.y;
    _q3 = q.z;
    _daChay += dt;
  }
}
