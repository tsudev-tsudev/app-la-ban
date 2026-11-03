import 'dart:math' as math;

import 'package:meta/meta.dart';

// Vị trí mặt trời / mặt trăng ngoại tuyến (Meeus, "Astronomical Algorithms"
// ch.25 và ch.47 rút gọn các số hạng lớn). Sai số so ephem: mặt trời < 0,02°,
// mặt trăng < 0,1°, giờ mọc / lặn < 1 phút - dư cho la bàn.

const double _rad = math.pi / 180;

double _chuanHoa(double d) => (d % 360 + 360) % 360;

/// Lệch TT - UT (giây), xấp xỉ cho 2020-2035 (sai vài giây không đáng kể).
const _deltaTGiay = 69.0;

/// Ngày Julius (UT) của thời điểm.
double ngayJulius(DateTime t) =>
    t.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;

double _theKy(double jdUt) => (jdUt + _deltaTGiay / 86400 - 2451545) / 36525;

/// Giờ sao trung bình Greenwich (độ).
double _gmst(double jd) {
  final t = (jd - 2451545) / 36525;
  return _chuanHoa(
    280.46061837 +
        360.98564736629 * (jd - 2451545) +
        0.000387933 * t * t -
        t * t * t / 38710000,
  );
}

typedef _XichDao = ({double xichKinh, double xichVi, double khoangCachKm});

_XichDao _tuHoangDao(double lambda, double beta, double t, double km) {
  final eps = (23.4392911 - 0.0130042 * t) * _rad;
  final l = lambda * _rad;
  final b = beta * _rad;
  final ra = math.atan2(
    math.sin(l) * math.cos(eps) - math.tan(b) * math.sin(eps),
    math.cos(l),
  );
  final dec = math.asin(
    math.sin(b) * math.cos(eps) + math.cos(b) * math.sin(eps) * math.sin(l),
  );
  return (xichKinh: _chuanHoa(ra / _rad), xichVi: dec / _rad, khoangCachKm: km);
}

_XichDao _matTroi(double jd) {
  final t = _theKy(jd);
  final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
  final m = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) * _rad;
  final e = 0.016708634 - 0.000042037 * t;
  final c =
      (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(m) +
      (0.019993 - 0.000101 * t) * math.sin(2 * m) +
      0.000289 * math.sin(3 * m);
  final omega = (125.04 - 1934.136 * t) * _rad;
  final lambda = l0 + c - 0.00569 - 0.00478 * math.sin(omega);
  final r = 1.000001018 * (1 - e * e) / (1 + e * math.cos(m + c * _rad));
  return _tuHoangDao(lambda, 0, t, r * 149597870.7);
}

// Bảng 47.A (D, M, M', F, Σl 1e-6°, Σr m) và 47.B (D, M, M', F, Σb 1e-6°).
const _bangLR = <List<int>>[
  [0, 0, 1, 0, 6288774, -20905355],
  [2, 0, -1, 0, 1274027, -3699111],
  [2, 0, 0, 0, 658314, -2955968],
  [0, 0, 2, 0, 213618, -569925],
  [0, 1, 0, 0, -185116, 48888],
  [0, 0, 0, 2, -114332, -3149],
  [2, 0, -2, 0, 58793, 246158],
  [2, -1, -1, 0, 57066, -152138],
  [2, 0, 1, 0, 53322, -170733],
  [2, -1, 0, 0, 45758, -204586],
  [0, 1, -1, 0, -40923, -129620],
  [1, 0, 0, 0, -34720, 108743],
  [0, 1, 1, 0, -30383, 104755],
  [2, 0, 0, -2, 15327, 10321],
  [0, 0, 1, 2, -12528, 0],
  [0, 0, 1, -2, 10980, 79661],
  [4, 0, -1, 0, 10675, -34782],
  [0, 0, 3, 0, 10034, -23210],
  [4, 0, -2, 0, 8548, -21636],
  [2, 1, -1, 0, -7888, 24208],
  [2, 1, 0, 0, -6766, 30824],
  [1, 0, -1, 0, -5163, -8379],
  [1, 1, 0, 0, 4987, -16675],
  [2, -1, 1, 0, 4036, -12831],
  [2, 0, 2, 0, 3994, -10445],
  [4, 0, 0, 0, 3861, -11650],
  [2, 0, -3, 0, 3665, 14403],
  [0, 1, -2, 0, -2689, -7003],
  [2, 0, -1, 2, -2602, 0],
  [2, -1, -2, 0, 2390, 10056],
  [1, 0, 1, 0, -2348, 6322],
  [2, -2, 0, 0, 2236, -9884],
];

const _bangB = <List<int>>[
  [0, 0, 0, 1, 5128122],
  [0, 0, 1, 1, 280602],
  [0, 0, 1, -1, 277693],
  [2, 0, 0, -1, 173237],
  [2, 0, -1, 1, 55413],
  [2, 0, -1, -1, 46271],
  [2, 0, 0, 1, 32573],
  [0, 0, 2, 1, 17198],
  [2, 0, 1, -1, 9266],
  [0, 0, 2, -1, 8822],
  [2, -1, 0, -1, 8216],
  [2, 0, -2, -1, 4324],
  [2, 0, 1, 1, 4200],
  [2, 1, 0, -1, -3359],
  [2, -1, -1, 1, 2463],
  [2, -1, 0, 1, 2211],
  [2, -1, -1, -1, 2065],
  [0, 1, -1, -1, -1870],
  [4, 0, -1, -1, 1828],
  [0, 1, 0, 1, -1794],
  [0, 0, 0, 3, -1749],
  [0, 1, -1, 1, -1565],
  [1, 0, 0, 1, -1491],
  [0, 1, 1, 1, -1475],
  [0, 1, 1, -1, -1410],
  [0, 1, 0, -1, -1344],
  [1, 0, 0, -1, -1335],
  [0, 0, 3, 1, 1107],
];

_XichDao _matTrang(double jd) {
  final t = _theKy(jd);
  final t2 = t * t;
  final t3 = t2 * t;
  final t4 = t3 * t;
  final lp =
      218.3164477 +
      481267.88123421 * t -
      0.0015786 * t2 +
      t3 / 538841 -
      t4 / 65194000;
  final d =
      297.8501921 +
      445267.1114034 * t -
      0.0018819 * t2 +
      t3 / 545868 -
      t4 / 113065000;
  final m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000;
  final mp =
      134.9633964 +
      477198.8675055 * t +
      0.0087414 * t2 +
      t3 / 69699 -
      t4 / 14712000;
  final f =
      93.2720950 +
      483202.0175233 * t -
      0.0036539 * t2 -
      t3 / 3526000 +
      t4 / 863310000;
  final a1 = 119.75 + 131.849 * t;
  final a2 = 53.09 + 479264.290 * t;
  final a3 = 313.45 + 481266.484 * t;
  final e = 1 - 0.002516 * t - 0.0000074 * t2;
  double heSoE(int mm) => switch (mm.abs()) {
    1 => e,
    2 => e * e,
    _ => 1,
  };
  double sinD(double x) => math.sin(x * _rad);
  var sl = 0.0;
  var sr = 0.0;
  var sb = 0.0;
  for (final h in _bangLR) {
    final arg = h[0] * d + h[1] * m + h[2] * mp + h[3] * f;
    final k = heSoE(h[1]);
    sl += h[4] * k * sinD(arg);
    sr += h[5] * k * math.cos(arg * _rad);
  }
  for (final h in _bangB) {
    sb += h[4] * heSoE(h[1]) * sinD(h[0] * d + h[1] * m + h[2] * mp + h[3] * f);
  }
  sl += 3958 * sinD(a1) + 1962 * sinD(lp - f) + 318 * sinD(a2);
  sb +=
      -2235 * sinD(lp) +
      382 * sinD(a3) +
      175 * sinD(a1 - f) +
      175 * sinD(a1 + f) +
      127 * sinD(lp - mp) -
      115 * sinD(lp + mp);
  return _tuHoangDao(
    _chuanHoa(lp + sl / 1e6),
    sb / 1e6,
    t,
    385000.56 + sr / 1000,
  );
}

/// Phương vị (từ bắc thực, theo chiều kim đồng hồ) và độ cao hình học tâm
/// thiên thể (độ) - đã hiệu chỉnh thị sai, CHƯA cộng khúc xạ.
typedef ViTriBauTroi = ({double phuongVi, double doCao});

const _banKinhTraiDatKm = 6378.14;

ViTriBauTroi _ngang(_XichDao x, double jd, double viDo, double kinhDo) {
  final h = (_gmst(jd) + kinhDo - x.xichKinh) * _rad;
  final phi = viDo * _rad;
  final dec = x.xichVi * _rad;
  final sinAlt =
      math.sin(phi) * math.sin(dec) +
      math.cos(phi) * math.cos(dec) * math.cos(h);
  var alt = math.asin(sinAlt.clamp(-1.0, 1.0));
  final az = math.atan2(
    math.sin(h),
    math.cos(h) * math.sin(phi) - math.tan(dec) * math.cos(phi),
  );
  // Thị sai chân trời (đáng kể với mặt trăng, ~1°).
  final thiSai = math.asin(_banKinhTraiDatKm / x.khoangCachKm);
  alt -= math.asin(math.sin(thiSai) * math.cos(alt));
  return (phuongVi: _chuanHoa(az / _rad + 180), doCao: alt / _rad);
}

/// Khúc xạ khí quyển chuẩn (Bennett, độ) cộng vào độ cao hình học để ra độ
/// cao nhìn thấy.
double khucXa(double doCao) {
  if (doCao < -1.5) return 0;
  final h = math.max(doCao, -1);
  return 1 / 60 / math.tan((h + 7.31 / (h + 4.4)) * _rad);
}

ViTriBauTroi viTriMatTroi(DateTime t, double viDo, double kinhDo) {
  final jd = ngayJulius(t);
  return _ngang(_matTroi(jd), jd, viDo, kinhDo);
}

ViTriBauTroi viTriMatTrang(DateTime t, double viDo, double kinhDo) {
  final jd = ngayJulius(t);
  return _ngang(_matTrang(jd), jd, viDo, kinhDo);
}

/// Pha mặt trăng: phần đĩa được chiếu sáng [0, 1] và góc pha theo tuổi trăng
/// [0, 360) (0 = trăng mới, 180 = trăng tròn).
typedef PhaTrang = ({double sang, double goc});

PhaTrang phaMatTrang(DateTime t) {
  final jd = ngayJulius(t);
  final s = _matTroi(jd);
  final m = _matTrang(jd);
  double vec(double ra, double dec, int i) {
    final r = ra * _rad;
    final d = dec * _rad;
    return switch (i) {
      0 => math.cos(d) * math.cos(r),
      1 => math.cos(d) * math.sin(r),
      _ => math.sin(d),
    };
  }

  var cosPsi = 0.0;
  for (var i = 0; i < 3; i++) {
    cosPsi += vec(s.xichKinh, s.xichVi, i) * vec(m.xichKinh, m.xichVi, i);
  }
  final psi = math.acos(cosPsi.clamp(-1.0, 1.0));
  final i = math.atan2(
    s.khoangCachKm * math.sin(psi),
    m.khoangCachKm - s.khoangCachKm * math.cos(psi),
  );
  // Tuổi trăng: hiệu kinh độ xích đạo (đủ để biết trăng non hay già).
  final hieu = _chuanHoa(m.xichKinh - s.xichKinh);
  return (sang: (1 + math.cos(i)) / 2, goc: hieu);
}

/// 8 pha trăng gọi tên.
enum TenPhaTrang {
  trangMoi,
  luoiLiemDau,
  thuongHuyen,
  traiMoDau,
  trangTron,
  traiMoCuoi,
  haHuyen,
  luoiLiemCuoi,
}

TenPhaTrang tenPha(PhaTrang p) =>
    TenPhaTrang.values[((p.goc + 22.5) / 45).floor() % 8];

/// Mọc / lặn / qua kinh tuyến trong một khoảng 24 giờ.
@immutable
final class SuKienNgay {
  const new({this.moc, this.lan, this.dinh, this.luonTren = false});

  final DateTime? moc;
  final DateTime? lan;

  /// Lúc qua kinh tuyến trên (trưa thực với mặt trời).
  final DateTime? dinh;

  /// Không mọc / lặn trong khoảng: true = ở trên chân trời suốt (ngày địa
  /// cực), false = dưới suốt (khi [moc] và [lan] đều null).
  final bool luonTren;
}

/// Ngưỡng độ cao tâm khi mọc / lặn (độ): mặt trời -0°50' (khúc xạ 34' + bán
/// kính 16'); mặt trăng -34' trừ bán kính biểu kiến (~15,5').
const nguongMatTroi = -0.8333;

SuKienNgay _tim(
  ViTriBauTroi Function(DateTime) viTri,
  double Function(DateTime) nguong,
  DateTime tu,
) {
  const buoc = Duration(minutes: 10);
  final den = tu.add(const Duration(hours: 24));
  double f(DateTime t) => viTri(t).doCao - nguong(t);
  // Góc giờ ~ phương vị qua 180°: đổi dấu sin(phương vị) từ + sang -.
  double g(DateTime t) => math.sin(viTri(t).phuongVi * _rad);

  DateTime chiaDoi(DateTime tu, DateTime den, double Function(DateTime) h) {
    var a = tu;
    var b = den;
    final ha = h(a);
    for (var i = 0; i < 20; i++) {
      final giua = a.add(
        Duration(microseconds: b.difference(a).inMicroseconds ~/ 2),
      );
      if ((h(giua) > 0) == (ha > 0)) {
        a = giua;
      } else {
        b = giua;
      }
    }
    return a.add(Duration(microseconds: b.difference(a).inMicroseconds ~/ 2));
  }

  DateTime? moc;
  DateTime? lan;
  DateTime? dinh;
  var t0 = tu;
  var f0 = f(t0);
  var g0 = g(t0);
  var tren = f0 > 0;
  var luonTren = tren;
  while (t0.isBefore(den)) {
    final t1 = t0.add(buoc);
    final f1 = f(t1);
    final g1 = g(t1);
    if (f0 <= 0 && f1 > 0) {
      moc ??= chiaDoi(t0, t1, f);
      luonTren = false;
    } else if (f0 > 0 && f1 <= 0) {
      lan ??= chiaDoi(t0, t1, f);
      luonTren = false;
    }
    // Qua phương vị nam (bắc bán cầu) hoặc bắc (thiên thể ở phía bắc đỉnh
    // đầu): chỉ nhận lúc độ cao lớn hơn lần đổi dấu đối diện.
    if ((g0 > 0) != (g1 > 0)) {
      final c = chiaDoi(t0, t1, g);
      final cao = viTri(c).doCao;
      if (dinh == null || cao > viTri(dinh).doCao) dinh = c;
    }
    tren = f1 > 0;
    t0 = t1;
    f0 = f1;
    g0 = g1;
  }
  return SuKienNgay(moc: moc, lan: lan, dinh: dinh, luonTren: luonTren && tren);
}

/// Sự kiện mặt trời trong 24 giờ kể từ [tu].
SuKienNgay suKienMatTroi(DateTime tu, double viDo, double kinhDo) =>
    _tim((t) => viTriMatTroi(t, viDo, kinhDo), (_) => nguongMatTroi, tu);

/// Sự kiện mặt trăng trong 24 giờ kể từ [tu] (mép trên chạm chân trời).
SuKienNgay suKienMatTrang(DateTime tu, double viDo, double kinhDo) =>
    _tim((t) => viTriMatTrang(t, viDo, kinhDo), (t) {
      final km = _matTrang(ngayJulius(t)).khoangCachKm;
      // Bán kính biểu kiến địa tâm (độ).
      final banKinh = math.asin(1737.4 / km) / _rad;
      return -34 / 60 - banKinh;
    }, tu);
