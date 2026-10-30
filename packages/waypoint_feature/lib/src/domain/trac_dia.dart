import 'dart:math';

/// Kết quả bài toán ngược trắc địa giữa hai điểm.
typedef KetQuaTracDia = ({
  /// Khoảng cách trên elipxoit WGS84 (m).
  double khoangCachM,

  /// Phương vị ban đầu tại điểm đầu, độ [0, 360) (bắc thực).
  double phuongViDau,

  /// Phương vị khi tới điểm cuối (hướng đi tiếp), độ [0, 360).
  double phuongViCuoi,
});

const _a = 6378137.0;
const double _f = 1 / 298.257223563;
const double _b = _a * (1 - _f);

/// Bán kính trung bình (m) cho phương án dự phòng trên mặt cầu.
const _rTrungBinh = 6371008.8;

double _rad(double d) => d * pi / 180;
double _do(double r) => r * 180 / pi;

/// Chuẩn hoá góc về [0, 360).
double chuanHoa360(double d) {
  final r = d % 360;
  return r < 0 ? r + 360 : r;
}

/// Góc lệch có dấu từ [tu] sang [den], trong (-180, 180]. Dương = quay phải.
double gocLech(double tu, double den) {
  final d = chuanHoa360(den - tu);
  return d > 180 ? d - 360 : d;
}

/// Bài toán ngược Vincenty (1975) trên WGS84: chính xác cỡ mm. Hai điểm gần
/// đối cực (không hội tụ sau 200 vòng) -> công thức mặt cầu (sai số < 0,5%).
KetQuaTracDia tracDia(double vi1, double kinh1, double vi2, double kinh2) {
  final l = _rad(kinh2 - kinh1);
  final u1 = atan((1 - _f) * tan(_rad(vi1)));
  final u2 = atan((1 - _f) * tan(_rad(vi2)));
  final sinU1 = sin(u1);
  final cosU1 = cos(u1);
  final sinU2 = sin(u2);
  final cosU2 = cos(u2);

  var lambda = l;
  double sinSigma = 0;
  double cosSigma = 0;
  double sigma = 0;
  double cos2Alpha = 0;
  double cos2SigmaM = 0;
  double sinLambda = 0;
  double cosLambda = 0;
  var hoiTu = false;
  for (var i = 0; i < 200; i++) {
    sinLambda = sin(lambda);
    cosLambda = cos(lambda);
    final t1 = cosU2 * sinLambda;
    final t2 = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda;
    sinSigma = sqrt(t1 * t1 + t2 * t2);
    if (sinSigma == 0) {
      // Trùng điểm.
      return (khoangCachM: 0, phuongViDau: 0, phuongViCuoi: 0);
    }
    cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
    sigma = atan2(sinSigma, cosSigma);
    final sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
    cos2Alpha = 1 - sinAlpha * sinAlpha;
    // Hai điểm trên xích đạo: cos2Alpha = 0.
    cos2SigmaM = cos2Alpha == 0 ? 0 : cosSigma - 2 * sinU1 * sinU2 / cos2Alpha;
    final c = _f / 16 * cos2Alpha * (4 + _f * (4 - 3 * cos2Alpha));
    final truoc = lambda;
    lambda =
        l +
        (1 - c) *
            _f *
            sinAlpha *
            (sigma +
                c *
                    sinSigma *
                    (cos2SigmaM +
                        c * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)));
    if ((lambda - truoc).abs() < 1e-12) {
      hoiTu = true;
      break;
    }
  }
  if (!hoiTu) return _matCau(vi1, kinh1, vi2, kinh2);

  final u2s = cos2Alpha * (_a * _a - _b * _b) / (_b * _b);
  final aa = 1 + u2s / 16384 * (4096 + u2s * (-768 + u2s * (320 - 175 * u2s)));
  final bb = u2s / 1024 * (256 + u2s * (-128 + u2s * (74 - 47 * u2s)));
  final deltaSigma =
      bb *
      sinSigma *
      (cos2SigmaM +
          bb /
              4 *
              (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) -
                  bb /
                      6 *
                      cos2SigmaM *
                      (-3 + 4 * sinSigma * sinSigma) *
                      (-3 + 4 * cos2SigmaM * cos2SigmaM)));
  final s = _b * aa * (sigma - deltaSigma);
  final a1 = atan2(
    cosU2 * sinLambda,
    cosU1 * sinU2 - sinU1 * cosU2 * cosLambda,
  );
  final a2 = atan2(
    cosU1 * sinLambda,
    -sinU1 * cosU2 + cosU1 * sinU2 * cosLambda,
  );
  return (
    khoangCachM: s,
    phuongViDau: chuanHoa360(_do(a1)),
    phuongViCuoi: chuanHoa360(_do(a2)),
  );
}

KetQuaTracDia _matCau(double vi1, double kinh1, double vi2, double kinh2) {
  final p1 = _rad(vi1);
  final p2 = _rad(vi2);
  final dl = _rad(kinh2 - kinh1);
  final h =
      pow(sin((p2 - p1) / 2), 2) + cos(p1) * cos(p2) * pow(sin(dl / 2), 2);
  final d = 2 * _rTrungBinh * asin(min(1, sqrt(h)));
  double pv(double x1, double x2, double dLon) => chuanHoa360(
    _do(
      atan2(
        sin(dLon) * cos(x2),
        cos(x1) * sin(x2) - sin(x1) * cos(x2) * cos(dLon),
      ),
    ),
  );
  return (
    khoangCachM: d,
    phuongViDau: pv(p1, p2, dl),
    phuongViCuoi: chuanHoa360(pv(p2, p1, -dl) + 180),
  );
}
