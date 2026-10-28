import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Định dạng hiển thị toạ độ.
enum DinhDangToaDo {
  /// Độ thập phân: `21.028511, 105.804817`.
  dd,

  /// Độ - phút - giây: `21°01'42.6"N 105°48'17.3"E`.
  dms,

  /// UTM WGS84: `48Q 583630 2325514`.
  utm,

  /// MGRS (lưới quân sự, 1 m): `48Q WJ 83629 25513`.
  mgrs,
}

/// Độ thập phân có dấu, 6 chữ số (~0,1 m) - dạng dán được vào bản đồ.
String dinhDangDD(double viDo, double kinhDo) =>
    '${viDo.toStringAsFixed(6)}, ${kinhDo.toStringAsFixed(6)}';

/// Một trục độ - phút - giây; giây làm tròn 0,1" (~3 m) và nhớ sang phút /
/// độ (59,96" -> 1'00,0" chứ không ra 60,0").
String dinhDangMotTrucDMS(double goc, {required bool laViDo}) {
  final duong = goc >= 0;
  final phanMuoiGiay = (goc.abs() * 36000).round();
  final d = phanMuoiGiay ~/ 36000;
  final m = (phanMuoiGiay % 36000) ~/ 600;
  final s = (phanMuoiGiay % 600) / 10;
  final huong = laViDo ? (duong ? 'N' : 'S') : (duong ? 'E' : 'W');
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toStringAsFixed(1).padLeft(4, '0');
  return '$d°$mm\'$ss"$huong';
}

String dinhDangDMS(double viDo, double kinhDo) =>
    '${dinhDangMotTrucDMS(viDo, laViDo: true)} '
    '${dinhDangMotTrucDMS(kinhDo, laViDo: false)}';

/// Toạ độ UTM trên WGS84.
@immutable
final class ToaDoUtm {
  const new({
    required this.vung,
    required this.chuDai,
    required this.dong,
    required this.bac,
  });

  /// Múi 1-60.
  final int vung;

  /// Chữ đai vĩ độ C..X (bỏ I, O).
  final String chuDai;

  /// Easting (m, có 500 000 m dịch giả).
  final double dong;

  /// Northing (m; Nam bán cầu đã cộng 10 000 000 m).
  final double bac;

  bool get bacBanCau => chuDai.compareTo('N') >= 0;

  @override
  String toString() => '$vung$chuDai ${dong.floor()} ${bac.floor()}';
}

const _a = 6378137.0;
const _f = 1 / 298.257223563;
const _k0 = 0.9996;
const _chuDai = 'CDEFGHJKLMNPQRSTUVWX';

// Chuỗi Krüger bậc 6 (Karney 2011) - sai số < 1 mm trong múi.
final _n = _f / (2 - _f);
final _e = math.sqrt(_f * (2 - _f));
final _bigA = () {
  final n2 = _n * _n;
  return _a / (1 + _n) * (1 + n2 / 4 + n2 * n2 / 64 + n2 * n2 * n2 / 256);
}();
final _alpha = () {
  final n = _n;
  final n2 = n * n, n3 = n2 * n, n4 = n3 * n, n5 = n4 * n, n6 = n5 * n;
  return [
    n / 2 -
        2 * n2 / 3 +
        5 * n3 / 16 +
        41 * n4 / 180 -
        127 * n5 / 288 +
        7891 * n6 / 37800,
    13 * n2 / 48 -
        3 * n3 / 5 +
        557 * n4 / 1440 +
        281 * n5 / 630 -
        1983433 * n6 / 1935360,
    61 * n3 / 240 - 103 * n4 / 140 + 15061 * n5 / 26880 + 167603 * n6 / 181440,
    49561 * n4 / 161280 - 179 * n5 / 168 + 6601661 * n6 / 7257600,
    34729 * n5 / 80640 - 3418889 * n6 / 1995840,
    212378941 * n6 / 319334400,
  ];
}();

double _atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));
double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;

/// Múi UTM của điểm, kể cả ngoại lệ Na Uy (32V) và Svalbard (31X-37X).
int vungUtm(double viDo, double kinhDo) {
  final k = kinhDo >= 180 ? kinhDo - 360 : kinhDo;
  var z = ((k + 180) / 6).floor() + 1;
  if (viDo >= 56 && viDo < 64 && k >= 3 && k < 12) z = 32;
  if (viDo >= 72 && viDo < 84 && k >= 0 && k < 42) {
    z = k < 9
        ? 31
        : k < 21
        ? 33
        : k < 33
        ? 35
        : 37;
  }
  return z;
}

/// WGS84 -> UTM. null ngoài phạm vi UTM (vĩ độ < -80° hoặc >= 84°, vùng cực
/// dùng UPS).
ToaDoUtm? sangUtm(double viDo, double kinhDo) {
  if (viDo < -80 || viDo >= 84 || !viDo.isFinite || !kinhDo.isFinite) {
    return null;
  }
  final z = vungUtm(viDo, kinhDo);
  final kinhTuyenTruc = (z - 1) * 6 - 180 + 3;
  var dl = kinhDo - kinhTuyenTruc;
  if (dl < -180) dl += 360;
  if (dl > 180) dl -= 360;
  final phi = viDo * math.pi / 180;
  final lam = dl * math.pi / 180;
  final sp = math.sin(phi);
  final t = _sinh(_atanh(sp) - _e * _atanh(_e * sp));
  final xiP = math.atan2(t, math.cos(lam));
  final etaP = _atanh(math.sin(lam) / math.sqrt(1 + t * t));
  var xi = xiP, eta = etaP;
  for (var j = 1; j <= 6; j++) {
    final a = _alpha[j - 1];
    xi += a * math.sin(2 * j * xiP) * _cosh(2 * j * etaP);
    eta += a * math.cos(2 * j * xiP) * _sinh(2 * j * etaP);
  }
  final dong = 500000 + _k0 * _bigA * eta;
  var bac = _k0 * _bigA * xi;
  if (viDo < 0) bac += 10000000;
  final dai = math.min(((viDo + 80) / 8).floor(), _chuDai.length - 1);
  return ToaDoUtm(vung: z, chuDai: _chuDai[dai], dong: dong, bac: bac);
}

String? dinhDangUtm(double viDo, double kinhDo) =>
    sangUtm(viDo, kinhDo)?.toString();

const _cotMgrs = ['ABCDEFGH', 'JKLMNPQR', 'STUVWXYZ'];
const _hangMgrs = 'ABCDEFGHJKLMNPQRSTUV';

/// MGRS chuẩn WGS84 (bảng chữ "AA"), [soChuSo] chữ số mỗi trục (5 = 1 m),
/// cắt cụt chứ không làm tròn (đúng quy ước MGRS). Dạng gọn không dấu
/// cách: `48QWJ8362925513`. null ngoài phạm vi UTM.
String? sangMgrs(double viDo, double kinhDo, {int soChuSo = 5}) {
  final u = sangUtm(viDo, kinhDo);
  if (u == null) return null;
  // Cắt cụt về mét trước (tránh 99999,9997 -> 100000).
  final e = u.dong.floor();
  final n = u.bac.floor();
  final bo = (u.vung - 1) % 3;
  final cot = _cotMgrs[bo][e ~/ 100000 - 1];
  final lech = u.vung.isEven ? 5 : 0;
  final hang = _hangMgrs[(n ~/ 100000 + lech) % 20];
  final chia = math.pow(10, 5 - soChuSo).toInt();
  String so(int v) => ((v % 100000) ~/ chia).toString().padLeft(soChuSo, '0');
  return '${u.vung}${u.chuDai}$cot$hang${so(e)}${so(n)}';
}

/// MGRS có dấu cách để đọc: `48Q WJ 83629 25513`.
String? dinhDangMgrs(double viDo, double kinhDo) {
  final m = sangMgrs(viDo, kinhDo);
  if (m == null) return null;
  final i = m.length - 14;
  return '${m.substring(0, i + 2)} ${m.substring(i + 2, i + 4)} '
      '${m.substring(i + 4, i + 9)} ${m.substring(i + 9)}';
}

/// Toạ độ theo [dd]; UTM / MGRS ngoài phạm vi (vùng cực) trả null.
String? dinhDangToaDo(DinhDangToaDo dd, double viDo, double kinhDo) =>
    switch (dd) {
      DinhDangToaDo.dd => dinhDangDD(viDo, kinhDo),
      DinhDangToaDo.dms => dinhDangDMS(viDo, kinhDo),
      DinhDangToaDo.utm => dinhDangUtm(viDo, kinhDo),
      DinhDangToaDo.mgrs => dinhDangMgrs(viDo, kinhDo),
    };
