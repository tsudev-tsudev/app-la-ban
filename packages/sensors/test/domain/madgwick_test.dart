import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

import '../mo_phong.dart';

/// Chạy Madgwick trên chuỗi mô phỏng, trả sai số phương vị lớn nhất sau
/// [boQua] giây đầu.
double chay(List<MauCamBien> ds, Quat Function(double) q, {double boQua = 2}) {
  final f = Madgwick();
  Vec3? a;
  Vec3? m;
  int? truoc;
  var lonNhat = 0.0;
  for (final s in ds) {
    switch (s.loai) {
      case LoaiMau.giaToc:
        a = Vec3(s.x, s.y, s.z);
      case LoaiMau.tu:
        m = Vec3(s.x, s.y, s.z);
      case LoaiMau.conQuay:
        if (a == null || m == null) continue;
        if (truoc == null) {
          f.datLai(quatTuGiaTocTu(a, m)!);
        } else {
          f.capNhat(Vec3(s.x, s.y, s.z), a, m, (s.tNs - truoc) / 1e9);
        }
        truoc = s.tNs;
        final t = (s.tNs - 1000000000) / 1e9;
        if (t >= boQua) {
          final e = saiSo(
            tuTheTuQuat(f.tuThe).phuongVi,
            tuTheTuQuat(q(t)).phuongVi,
          );
          if (e > lonNhat) lonNhat = e;
        }
      case LoaiMau.xoayVector ||
          LoaiMau.xoayGame ||
          LoaiMau.apSuat ||
          LoaiMau.xoayManHinh:
    }
  }
  return lonNhat;
}

void main() {
  test('đứng yên nghiêng: hội tụ và giữ sai số < 1°', () {
    Quat q(double _) => tuGoc(137, 20, -10);
    expect(chay(moPhong(q, thoiGian: 6), q), lessThan(1));
  });

  test('xoay 60°/s qua 359° -> 0° khi đang nghiêng: sai số < 2°', () {
    Quat q(double t) => tuGoc(300 + 60 * t, 15, 5);
    expect(chay(moPhong(q, thoiGian: 8), q), lessThan(2));
  });

  test('con quay lệch 0,01 rad/s: từ trường kéo lại, sai số < 3°', () {
    Quat q(double t) => tuGoc(45, 0, 0);
    expect(chay(moPhong(q, thoiGian: 10, lechQuay: 0.01), q), lessThan(3));
  });

  test('khởi tạo từ bù nghiêng: tư thế đúng ngay bước đầu', () {
    final f = Madgwick()..datLai(tuGoc(210, 10, 0));
    expect(saiSo(tuTheTuQuat(f.tuThe).phuongVi, 210), lessThan(1e-6));
  });

  test('từ trường null (nhiễu) -> chỉ con quay + gia tốc, giữ hướng', () {
    final q0 = tuGoc(100, 0, 0);
    final f = Madgwick()..datLai(q0);
    final a = q0.xoayNguoc(trongLuc);
    for (var i = 0; i < 300; i++) {
      f.capNhat(Vec3.zero, a, null, 0.01);
    }
    expect(saiSo(tuTheTuQuat(f.tuThe).phuongVi, 100), lessThan(0.5));
  });

  test('IMU-only: gia tốc kéo tư thế nghiêng về đúng', () {
    final f = Madgwick(beta: 0.5)..datLai(tuGoc(0, 0, 0));
    final thuc = tuGoc(0, 20, 0);
    final a = thuc.xoayNguoc(trongLuc);
    for (var i = 0; i < 1000; i++) {
      f.capNhat(Vec3.zero, a, null, 0.01);
    }
    expect(tuTheTuQuat(f.tuThe).doc, closeTo(20, 0.5));
  });
}
