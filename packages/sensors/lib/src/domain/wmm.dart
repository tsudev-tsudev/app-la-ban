import 'dart:math' as math;

import 'package:sensors/src/domain/wmm2025_cof.dart';

/// Bộ hệ số Gauss của một World Magnetic Model (bậc tối đa [bac]).
///
/// Mảng phẳng chỉ số `n * (n + 1) ~/ 2 + m` (n 0..bac, m 0..n); ô n = 0 bỏ
/// trống. Đơn vị nT và nT/năm.
final class HeSoWmm {
  new _({
    required this.ten,
    required this.namGoc,
    required this.bac,
    required this._g,
    required this._h,
    required this._gDot,
    required this._hDot,
  });

  /// Đọc định dạng WMM.COF của NOAA: dòng đầu `năm  tên  ngày`, mỗi dòng sau
  /// `n m g h gDot hDot`, kết thúc ở dòng `9999...`. Sai định dạng -> ném
  /// [FormatException] (config ký số hỏng thì giữ bộ nhúng sẵn).
  factory tuCof(String cof) {
    final dong = cof
        .split('\n')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();
    if (dong.isEmpty) throw const FormatException('COF rỗng');
    final dau = dong.first.split(RegExp(r'\s+'));
    final namGoc = dau.isEmpty ? null : double.tryParse(dau.first);
    if (namGoc == null || dau.length < 2) {
      throw FormatException('dòng đầu COF lạ', dong.first);
    }
    final hang = <List<num>>[];
    var bac = 0;
    for (final d in dong.skip(1)) {
      if (d.startsWith('9999')) break;
      final o = d.split(RegExp(r'\s+'));
      final n = o.isNotEmpty ? int.tryParse(o[0]) : null;
      final m = o.length > 1 ? int.tryParse(o[1]) : null;
      final so = o.length == 6 ? o.skip(2).map(double.tryParse).toList() : null;
      if (n == null ||
          m == null ||
          n < 1 ||
          m < 0 ||
          m > n ||
          so == null ||
          so.any((x) => x == null || !x.isFinite)) {
        throw FormatException('dòng hệ số COF lạ', d);
      }
      hang.add([n, m, ...so.cast<double>()]);
      bac = math.max(bac, n);
    }
    if (bac == 0) throw const FormatException('COF không có hệ số');
    final kc = _chiSo(bac, bac) + 1;
    final g = List<double>.filled(kc, 0);
    final h = List<double>.filled(kc, 0);
    final gDot = List<double>.filled(kc, 0);
    final hDot = List<double>.filled(kc, 0);
    for (final r in hang) {
      final i = _chiSo(r[0].toInt(), r[1].toInt());
      g[i] = r[2].toDouble();
      h[i] = r[3].toDouble();
      gDot[i] = r[4].toDouble();
      hDot[i] = r[5].toDouble();
    }
    return HeSoWmm._(
      ten: dau[1],
      namGoc: namGoc,
      bac: bac,
      g: g,
      h: h,
      gDot: gDot,
      hDot: hDot,
    );
  }

  /// WMM2025 nhúng sẵn trong app.
  static final wmm2025 = HeSoWmm.tuCof(wmm2025Cof);

  /// Tên mô hình, ví dụ `WMM-2025`.
  final String ten;

  /// Năm thập phân gốc (epoch) của hệ số.
  final double namGoc;
  final int bac;
  final List<double> _g;
  final List<double> _h;
  final List<double> _gDot;
  final List<double> _hDot;

  /// Mô hình có hiệu lực 5 năm từ [namGoc].
  double get namHetHan => namGoc + 5;

  static int _chiSo(int n, int m) => n * (n + 1) ~/ 2 + m;
}

/// Kết quả tổng hợp từ trường tại một điểm (hệ trắc địa: X bắc, Y đông, Z
/// xuống). Góc theo độ, cường độ theo nT.
final class TuTruongDiaCau {
  const new({
    required this.x,
    required this.y,
    required this.z,
    required this.ngoaiHan,
  });

  final double x;
  final double y;
  final double z;

  /// Thời điểm nằm ngoài khoảng hiệu lực của mô hình (sai số tăng dần).
  final bool ngoaiHan;

  /// Cường độ ngang H.
  double get h => math.sqrt(x * x + y * y);

  /// Cường độ toàn phần F.
  double get f => math.sqrt(x * x + y * y + z * z);

  /// Độ lệch từ D (dương = bắc từ lệch về phía đông bắc thực). Bắc thực =
  /// phương vị từ + D.
  double get doLech => math.atan2(y, x) * 180 / math.pi;

  /// Độ từ khuynh I (dương = hướng xuống).
  double get doKhuynh => math.atan2(z, h) * 180 / math.pi;
}

// Elipxoit WGS84 và bán kính tham chiếu của WMM (km).
const _a = 6378.137;
const _b = 6356.7523142;
const _re = 6371.2;

/// Tổng hợp từ trường WMM tại vĩ độ / kinh độ trắc địa ([viDo], [kinhDo]
/// độ), độ cao [doCaoKm] trên elipxoit WGS84, thời điểm [nam] (năm thập phân,
/// xem [namThapPhan]). Vĩ độ được kẹp trong ±89,999° (cực từ / cực địa lý
/// không có độ lệch xác định).
TuTruongDiaCau tinhTuTruong(
  HeSoWmm hs, {
  required double viDo,
  required double kinhDo,
  required double nam,
  double doCaoKm = 0,
}) {
  final lat = viDo.clamp(-89.999, 89.999) * math.pi / 180;
  final lon = kinhDo * math.pi / 180;
  final dt = nam - hs.namGoc;
  final ngoaiHan = dt < 0 || nam > hs.namHetHan;

  // Trắc địa -> địa tâm (bán kính r, cos / sin góc cực, góc xoay psi).
  const a2 = _a * _a;
  const b2 = _b * _b;
  const c2 = a2 - b2;
  const a4 = a2 * a2;
  const b4 = b2 * b2;
  const c4 = a4 - b4;
  final sl = math.sin(lat);
  final cl = math.cos(lat);
  final sl2 = sl * sl;
  final cl2 = cl * cl;
  final q = math.sqrt(a2 - c2 * sl2);
  final q1 = doCaoKm * q;
  final q2 = math.pow((q1 + a2) / (q1 + b2), 2);
  final ct = sl / math.sqrt(q2 * cl2 + sl2);
  final st = math.sqrt(1 - ct * ct);
  final r = math.sqrt(doCaoKm * doCaoKm + 2 * q1 + (a4 - c4 * sl2) / (q * q));
  final d = math.sqrt(a2 * cl2 + b2 * sl2);
  final ca = (doCaoKm + d) / r;
  final sa = c2 * cl * sl / (r * d);

  // Hàm Legendre liên kết chuẩn hoá Schmidt P(n,m)(cos θ) và đạo hàm theo θ.
  final bac = hs.bac;
  final kc = HeSoWmm._chiSo(bac, bac) + 1;
  final p = List<double>.filled(kc, 0);
  final dp = List<double>.filled(kc, 0);
  p[0] = 1;
  for (var n = 1; n <= bac; n++) {
    for (var m = 0; m <= n; m++) {
      final i = HeSoWmm._chiSo(n, m);
      if (n == m) {
        final j = HeSoWmm._chiSo(n - 1, n - 1);
        final k = n == 1 ? 1.0 : math.sqrt((2 * n - 1) / (2 * n));
        p[i] = k * st * p[j];
        dp[i] = k * (ct * p[j] + st * dp[j]);
      } else {
        final j1 = HeSoWmm._chiSo(n - 1, m);
        final p2 = m <= n - 2 ? p[HeSoWmm._chiSo(n - 2, m)] : 0.0;
        final dp2 = m <= n - 2 ? dp[HeSoWmm._chiSo(n - 2, m)] : 0.0;
        final k2 = math.sqrt(((n - 1) * (n - 1) - m * m).toDouble());
        final mau = math.sqrt((n * n - m * m).toDouble());
        p[i] = ((2 * n - 1) * ct * p[j1] - k2 * p2) / mau;
        dp[i] = ((2 * n - 1) * (ct * dp[j1] - st * p[j1]) - k2 * dp2) / mau;
      }
    }
  }

  // Tổng điều hoà cầu: Br, Bθ, Bφ (hệ địa tâm).
  var br = 0.0;
  var bt = 0.0;
  var bp = 0.0;
  final tiLe = _re / r;
  var luyThua = tiLe * tiLe;
  for (var n = 1; n <= bac; n++) {
    luyThua *= tiLe;
    for (var m = 0; m <= n; m++) {
      final i = HeSoWmm._chiSo(n, m);
      final g = hs._g[i] + dt * hs._gDot[i];
      final h = hs._h[i] + dt * hs._hDot[i];
      final cm = math.cos(m * lon);
      final sm = math.sin(m * lon);
      final tong = g * cm + h * sm;
      br += luyThua * (n + 1) * tong * p[i];
      bt -= luyThua * tong * dp[i];
      bp += luyThua * m * (g * sm - h * cm) * p[i];
    }
  }
  bp /= st;

  // Địa tâm -> trắc địa.
  return TuTruongDiaCau(
    x: -bt * ca - br * sa,
    y: bp,
    z: bt * sa - br * ca,
    ngoaiHan: ngoaiHan,
  );
}

/// Năm thập phân của [t] (theo UTC), như WMM dùng: 2025-07-02 12:00 ~ 2025.5.
double namThapPhan(DateTime t) {
  final u = t.toUtc();
  final dau = DateTime.utc(u.year);
  final sau = DateTime.utc(u.year + 1);
  return u.year +
      u.difference(dau).inMicroseconds / sau.difference(dau).inMicroseconds;
}
