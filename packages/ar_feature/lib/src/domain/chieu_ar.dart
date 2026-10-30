import 'dart:math' as math;

// A7c - phần thuần của Camera AR: chiếu một hướng (phương vị + góc ngóc) lên
// khung hình camera theo mô hình lỗ kim. Không ARCore / ARKit: tư thế máy lấy
// từ bộ hợp nhất cảm biến (sensors), trường nhìn từ thông số camera.

/// Tư thế camera sau (độ): phương vị bắc thực, góc ngóc (nhìn lên dương),
/// góc nghiêng ngang của màn hình (mép phải nâng lên dương).
typedef TuTheCamera = ({double phuongVi, double ngoc, double lan});

/// Trường nhìn (độ) theo chiều ngang / dọc của KHUNG ĐANG HIỂN THỊ.
typedef TruongNhin = ({double ngang, double doc});

/// Toạ độ điểm ảnh trên khung (gốc trên trái).
typedef DiemManHinh = ({double x, double y});

double _rad(double d) => d * math.pi / 180;
double _do(double r) => r * 180 / math.pi;

/// Trường nhìn của khung [rong] x [cao] khi ảnh camera (trường nhìn [anh],
/// tỉ lệ [tiLeAnh] = rộng / cao, ĐÃ xoay theo màn hình) phủ kín khung kiểu
/// BoxFit.cover: chiều bị cắt có trường nhìn hẹp lại.
TruongNhin truongNhinPhuKin(
  TruongNhin anh,
  double tiLeAnh,
  double rong,
  double cao,
) {
  final tiLeKhung = rong / cao;
  double hep(double fov, double tiLe) =>
      _do(2 * math.atan(math.tan(_rad(fov) / 2) * tiLe));
  // Khung "dài" hơn ảnh theo chiều ngang -> cắt trên dưới, ngược lại cắt hai
  // bên.
  return tiLeKhung >= tiLeAnh
      ? (ngang: anh.ngang, doc: hep(anh.doc, tiLeAnh / tiLeKhung))
      : (ngang: hep(anh.ngang, tiLeKhung / tiLeAnh), doc: anh.doc);
}

/// Vectơ đơn vị ENU (Đông, Bắc, Lên) của hướng [phuongVi] / [ngoc] (độ).
({double x, double y, double z}) _huong(double phuongVi, double ngoc) {
  final a = _rad(phuongVi);
  final e = _rad(ngoc);
  return (
    x: math.sin(a) * math.cos(e),
    y: math.cos(a) * math.cos(e),
    z: math.sin(e),
  );
}

double _cham(
  ({double x, double y, double z}) a,
  ({double x, double y, double z}) b,
) => a.x * b.x + a.y * b.y + a.z * b.z;

/// Chiếu hướng ([phuongVi], [ngoc]) lên khung [rong] x [cao]. null khi hướng
/// ở sau lưng camera (lệch >= ~90°). Điểm có thể nằm ngoài khung - người gọi
/// tự quyết vẽ mũi tên ở mép.
DiemManHinh? chieuLenKhung({
  required double phuongVi,
  required TuTheCamera camera,
  required TruongNhin truongNhin,
  required double rong,
  required double cao,
  double ngoc = 0,
}) {
  final h = _rad(camera.phuongVi);
  final p = _rad(camera.ngoc);
  final r = _rad(camera.lan);
  final truoc = _huong(camera.phuongVi, camera.ngoc);
  // Trục phải / lên của camera khi chưa nghiêng ngang.
  final phai0 = (x: math.cos(h), y: -math.sin(h), z: 0.0);
  final len0 = (
    x: -math.sin(h) * math.sin(p),
    y: -math.cos(h) * math.sin(p),
    z: math.cos(p),
  );
  // Mép phải nâng lên [lan] độ -> trục phải nghiêng về phía trục lên.
  final phai = (
    x: phai0.x * math.cos(r) + len0.x * math.sin(r),
    y: phai0.y * math.cos(r) + len0.y * math.sin(r),
    z: phai0.z * math.cos(r) + len0.z * math.sin(r),
  );
  final len = (
    x: len0.x * math.cos(r) - phai0.x * math.sin(r),
    y: len0.y * math.cos(r) - phai0.y * math.sin(r),
    z: len0.z * math.cos(r) - phai0.z * math.sin(r),
  );
  final t = _huong(phuongVi, ngoc);
  final z = _cham(t, truoc);
  if (z < 0.05) return null;
  final fx = rong / 2 / math.tan(_rad(truongNhin.ngang) / 2);
  final fy = cao / 2 / math.tan(_rad(truongNhin.doc) / 2);
  return (
    x: rong / 2 + _cham(t, phai) / z * fx,
    y: cao / 2 - _cham(t, len) / z * fy,
  );
}

/// Góc lệch có dấu (-180, 180] từ [tu] tới [den]: dương = phía phải.
double gocLechAr(double tu, double den) {
  final d = ((den - tu) % 360 + 360) % 360;
  return d > 180 ? d - 360 : d;
}

/// Góc ngóc (độ) nhìn tới điểm cách [khoangCachM] và cao hơn [chenhCaoM]
/// (âm = thấp hơn). Gần như 0 với điểm xa - nhãn nằm trên đường chân trời.
double gocNgocToi(double khoangCachM, double chenhCaoM) =>
    khoangCachM <= 0 ? 0 : _do(math.atan2(chenhCaoM, khoangCachM));

/// Phương vị vạch chia trên đường chân trời: mỗi [buoc] độ, chỉ những vạch
/// lệch không quá [nuaTruongNhin] + 1 bước so với [huong] (đủ phủ khung).
List<double> vachChanTroi(double huong, double nuaTruongNhin, {int buoc = 15}) {
  final ds = <double>[];
  for (var g = 0; g < 360; g += buoc) {
    if (gocLechAr(huong, g.toDouble()).abs() <= nuaTruongNhin + buoc) {
      ds.add(g.toDouble());
    }
  }
  return ds;
}

/// Khoảng cách gọn để hiển thị: < 1 km theo mét (làm tròn 10 m khi >= 100 m),
/// còn lại km một chữ số thập phân (>= 100 km: số nguyên).
({double giaTri, bool km}) khoangCachGon(double m) {
  if (m < 100) return (giaTri: m.roundToDouble(), km: false);
  if (m < 1000) return (giaTri: (m / 10).round() * 10.0, km: false);
  final km = m / 1000;
  return (
    giaTri: km >= 100 ? km.roundToDouble() : (km * 10).round() / 10,
    km: true,
  );
}
