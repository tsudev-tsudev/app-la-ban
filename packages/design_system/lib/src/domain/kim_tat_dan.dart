import 'dart:math' as math;

/// Góc lệch (radian) của kim la bàn tại thời điểm [t] giây, dao động tắt dần
/// về 0 (hướng Bắc) - dùng cho hoạt ảnh logo ở splash / onboarding.
///
/// [bienDo] là góc lúc bắt đầu, [tanSo] số dao động mỗi giây, [heSoTat] tốc độ
/// tắt (lớn hơn -> dừng sớm hơn). t <= 0 trả [bienDo].
double gocKimTatDan(
  double t, {
  double bienDo = 0.9,
  double tanSo = 1.6,
  double heSoTat = 3.2,
}) {
  if (t <= 0) return bienDo;
  return bienDo * math.exp(-heSoTat * t) * math.cos(2 * math.pi * tanSo * t);
}
