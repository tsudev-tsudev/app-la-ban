import 'dart:math' as math;

/// Đổi độ -> radian.
double doSangRad(double d) => d * math.pi / 180;

/// Đổi radian -> độ.
double radSangDo(double r) => r * 180 / math.pi;

/// Góc về khoảng [0, 360).
double chuanHoaDo(double d) {
  final r = d % 360;
  // -0.0 % 360 = -0.0 và số rất nhỏ âm có thể làm tròn thành 360.
  return r >= 360 || r == 0 ? 0 : r;
}

/// Hiệu có dấu ngắn nhất `a - b`, trong khoảng (-180, 180]. 1° - 359° = +2°,
/// không phải -358° - gốc của hiện tượng "nhảy 359° -> 0°".
double hieuGoc(double a, double b) {
  final d = (a - b) % 360;
  return d > 180 ? d - 360 : d;
}

/// Kết quả thống kê vòng của một tập góc.
typedef ThongKeVong = ({
  /// Hướng trung bình [0, 360); NaN khi các góc triệt tiêu nhau (R ~ 0).
  double trungBinh,

  /// Độ dài vectơ kết quả trung bình R trong [0, 1] (1 = trùng nhau).
  double r,

  /// Độ lệch chuẩn vòng sqrt(-2 ln R), đơn vị độ.
  double doLechChuan,
});

/// Trung bình / độ lệch chuẩn vòng (circular statistics): cộng vectơ đơn vị
/// thay vì cộng số đo, nên 359° và 1° cho trung bình 0° chứ không phải 180°.
ThongKeVong thongKeVong(Iterable<double> dsDo) {
  var s = 0.0;
  var c = 0.0;
  var n = 0;
  for (final d in dsDo) {
    final r = doSangRad(d);
    s += math.sin(r);
    c += math.cos(r);
    n++;
  }
  if (n == 0) {
    return (trungBinh: double.nan, r: 0, doLechChuan: double.infinity);
  }
  return _tuTong(s, c, n);
}

ThongKeVong _tuTong(double s, double c, int n) {
  final r = (math.sqrt(s * s + c * c) / n).clamp(0.0, 1.0);
  final tb = r < 1e-9 ? double.nan : chuanHoaDo(radSangDo(math.atan2(s, c)));
  final lc = r <= 0 ? double.infinity : radSangDo(math.sqrt(-2 * math.log(r)));
  return (trungBinh: tb, r: r, doLechChuan: lc);
}

/// Cửa sổ trượt [dungLuong] góc gần nhất, thống kê vòng O(1) mỗi lần thêm.
final class CuaSoVong {
  new(this.dungLuong) : assert(dungLuong > 0, 'dungLuong phải > 0');

  final int dungLuong;
  final List<double> _sin = [];
  final List<double> _cos = [];
  var _dau = 0;
  var _s = 0.0;
  var _c = 0.0;

  int get soMau => _sin.length;

  void them(double d) {
    final r = doSangRad(d);
    final s = math.sin(r);
    final c = math.cos(r);
    if (_sin.length < dungLuong) {
      _sin.add(s);
      _cos.add(c);
    } else {
      _s -= _sin[_dau];
      _c -= _cos[_dau];
      _sin[_dau] = s;
      _cos[_dau] = c;
      _dau = (_dau + 1) % dungLuong;
    }
    _s += s;
    _c += c;
  }

  void xoa() {
    _sin.clear();
    _cos.clear();
    _dau = 0;
    _s = 0;
    _c = 0;
  }

  ThongKeVong get thongKe => soMau == 0
      ? (trungBinh: double.nan, r: 0, doLechChuan: double.infinity)
      : _tuTong(_s, _c, soMau);
}

/// 8 hướng chính, theo chiều kim đồng hồ từ Bắc.
enum HuongChinh { bac, dongBac, dong, dongNam, nam, tayNam, tay, tayBac }

/// Hướng chính gần nhất của [d] độ (mỗi hướng phủ 45°, Bắc = [337,5; 22,5)).
HuongChinh huongChinh(double d) =>
    HuongChinh.values[((chuanHoaDo(d) + 22.5) ~/ 45) % 8];
