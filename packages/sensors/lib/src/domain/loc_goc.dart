import 'dart:math' as math;

import 'package:sensors/src/domain/goc_vong.dart';

/// Kalman 2 trạng thái (góc, tốc độ góc) cho góc VÒNG: phần đổi mới
/// (innovation) tính bằng [hieuGoc] nên đi qua 359° -> 0° không gây giật.
final class KalmanGoc {
  /// [nhieuQuaTrinh]: phương sai gia tốc góc (độ²/s⁴) - lớn bám nhanh hơn.
  new({this.nhieuQuaTrinh = 4000});

  final double nhieuQuaTrinh;

  double? _goc;
  var _tocDo = 0.0;
  // Hiệp phương sai P (đối xứng).
  var _p00 = 1e4;
  var _p01 = 0.0;
  var _p11 = 1e4;

  /// Góc ước lượng [0, 360), null khi chưa có đo đạc nào.
  double? get goc => _goc;

  /// Tốc độ quay ước lượng (độ/s).
  double get tocDo => _tocDo;

  void datLai() {
    _goc = null;
    _tocDo = 0;
    _p00 = 1e4;
    _p01 = 0;
    _p11 = 1e4;
  }

  /// Dự đoán [dt] giây rồi hiệu chỉnh bằng đo đạc [z] độ có phương sai
  /// [phuongSai] (độ²). Trả góc ước lượng mới.
  double capNhat(double z, double dt, {required double phuongSai}) {
    final g = _goc;
    if (g == null) {
      _goc = chuanHoaDo(z);
      _p00 = phuongSai;
      return _goc!;
    }
    // Dự đoán: x = F x, P = F P Fᵀ + Q (mô hình vận tốc không đổi).
    final t = dt.clamp(0.0, 0.5);
    var goc = g + _tocDo * t;
    final q = nhieuQuaTrinh;
    final t2 = t * t;
    var p00 = _p00 + 2 * t * _p01 + t2 * _p11 + q * t2 * t2 / 4;
    var p01 = _p01 + t * _p11 + q * t2 * t / 2;
    var p11 = _p11 + q * t2;
    // Hiệu chỉnh với H = [1, 0].
    final y = hieuGoc(z, goc);
    final s = p00 + phuongSai;
    final k0 = p00 / s;
    final k1 = p01 / s;
    goc += k0 * y;
    _tocDo += k1 * y;
    p11 -= k1 * p01;
    p01 -= k0 * p01;
    p00 -= k0 * p00;
    _p00 = p00;
    _p01 = p01;
    _p11 = p11;
    _goc = chuanHoaDo(goc);
    return _goc!;
  }
}

/// Lọc thông thấp THÍCH ỨNG cho góc vòng: rung nhỏ (nhiễu khi cầm yên) bị
/// làm mượt mạnh, quay lớn / nhanh thì bám gần như tức thì - chống "giật
/// kim" mà không trễ khi người dùng xoay người.
final class LocThichUng {
  /// Hằng số thời gian (giây) từ [tauCham] (thay đổi <= [nguongNho] độ) giảm
  /// tuyến tính về [tauNhanh] (thay đổi >= [nguongLon] độ).
  new({
    this.tauCham = 0.25,
    this.tauNhanh = 0.03,
    this.nguongNho = 1,
    this.nguongLon = 10,
  });

  final double tauCham;
  final double tauNhanh;
  final double nguongNho;
  final double nguongLon;

  double? _y;

  double? get giaTri => _y;

  void datLai() => _y = null;

  /// Hệ số trộn alpha trong (0, 1] cho độ lệch [lech] độ sau [dt] giây.
  double alpha(double lech, double dt) {
    final k = ((lech.abs() - nguongNho) / (nguongLon - nguongNho)).clamp(
      0.0,
      1.0,
    );
    final tau = tauCham + (tauNhanh - tauCham) * k;
    return 1 - math.exp(-math.max(0, dt) / tau);
  }

  /// Nạp [x] độ sau [dt] giây. [tocDo] (độ/s, ví dụ từ [KalmanGoc]) dùng để
  /// dự báo trước khi trộn - khi xoay đều kim không trễ sau hướng thật.
  double capNhat(double x, double dt, {double tocDo = 0}) {
    final y = _y;
    if (y == null) return _y = chuanHoaDo(x);
    final duBao = y + tocDo * math.max(0, dt);
    final lech = hieuGoc(x, duBao);
    return _y = chuanHoaDo(duBao + alpha(lech, dt) * lech);
  }
}
