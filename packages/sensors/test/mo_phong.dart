import 'dart:math' as math;

import 'package:sensors/sensors.dart';

/// Phản lực trọng trường (m/s²) và từ trường Hà Nội gần đúng (µT), khung ENU:
/// tổng ~45 µT, độ từ khuynh ~30° chúc xuống.
const trongLuc = Vec3(0, 0, 9.81);
const tuHaNoi = Vec3(0, 39, -22);

/// Quaternion máy -> ENU cho phương vị / ngóc / nghiêng ngang (độ) theo đúng
/// quy ước của [tuTheTuQuat] ở màn hình dọc.
Quat tuGoc(double phuongVi, double doc, double lan) =>
    Quat.quanhTruc(const Vec3(0, 0, 1), doSangRad(-phuongVi)) *
    Quat.quanhTruc(const Vec3(1, 0, 0), doSangRad(doc)) *
    Quat.quanhTruc(const Vec3(0, 1, 0), doSangRad(-lan));

/// Sinh chuỗi mẫu cảm biến cho quỹ đạo tư thế [q] (theo giây). Seed cố định
/// -> dữ liệu như ghi sẵn, test lặp lại được.
List<MauCamBien> moPhong(
  Quat Function(double t) q, {
  double thoiGian = 5,
  int hz = 100,
  double nhieuGiaToc = 0.05,
  double nhieuTu = 0.4,
  double nhieuQuay = 0.003,
  double lechQuay = 0,
  Vec3 Function(double t)? tuTruong,
  int doChinhXacTu = 3,
  int seed = 7,
  int tBatDauNs = 1000000000,
  bool coConQuay = true,
  bool coXoayVector = true,
}) {
  final r = math.Random(seed);
  double gauss() {
    final u = 1 - r.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * r.nextDouble());
  }

  Vec3 nhieu(Vec3 v, double s) =>
      Vec3(v.x + gauss() * s, v.y + gauss() * s, v.z + gauss() * s);

  final dt = 1 / hz;
  final ds = <MauCamBien>[];
  final n = (thoiGian * hz).round();
  for (var i = 0; i < n; i++) {
    final t = i * dt;
    final tNs = tBatDauNs + (t * 1e9).round();
    final qt = q(t);
    // Tốc độ góc trong khung máy: q(t)* ⊗ q(t+dt) = quay nhỏ quanh trục máy.
    final rel = qt.lienHop * q(t + dt);
    final dau = rel.w < 0 ? -1.0 : 1.0;
    final w = Vec3(rel.x, rel.y, rel.z) * (2 * dau / dt);
    final a = nhieu(qt.xoayNguoc(trongLuc), nhieuGiaToc);
    final m = nhieu(qt.xoayNguoc(tuTruong?.call(t) ?? tuHaNoi), nhieuTu);
    final g = nhieu(w, nhieuQuay) + Vec3(lechQuay, lechQuay, lechQuay);
    ds
      ..add(MauCamBien(LoaiMau.giaToc, tNs, x: a.x, y: a.y, z: a.z))
      ..add(
        MauCamBien(
          LoaiMau.tu,
          tNs,
          x: m.x,
          y: m.y,
          z: m.z,
          doChinhXac: doChinhXacTu,
        ),
      );
    if (coConQuay) {
      ds.add(MauCamBien(LoaiMau.conQuay, tNs, x: g.x, y: g.y, z: g.z));
    }
    if (coXoayVector) {
      ds.add(
        MauCamBien(LoaiMau.xoayVector, tNs, x: qt.x, y: qt.y, z: qt.z, w: qt.w),
      );
    }
  }
  return ds;
}

/// Sai số tuyệt đối vòng (độ).
double saiSo(double a, double b) => hieuGoc(a, b).abs();
