import 'dart:math' as math;

/// Góc nghiêng (độ) ứng với bọt chạm mép thước.
const gioiHanThuocDo = 10.0;

/// Trạng thái thước thuỷ (bubble level) từ góc ngóc / nghiêng của máy.
typedef ThuocThuy = ({
  /// Vị trí bọt trong đường tròn đơn vị, toạ độ màn hình (x sang phải, y
  /// xuống dưới). Bọt nổi về phía CAO.
  double x,
  double y,

  /// Góc giữa mặt kính và mặt phẳng ngang (độ).
  double nghieng,

  /// Đã cân bằng (có trễ để không nhấp nháy ở ngưỡng).
  bool canBang,
});

/// [doc]: mép trên nâng lên là dương; [lan]: mép phải nâng lên là dương
/// (quy ước `HuongDoc`). [canBangTruoc] là kết quả lần trước - vào cân bằng
/// khi < 0,5°, ra khi > 1°.
ThuocThuy tinhThuocThuy(double doc, double lan, {bool canBangTruoc = false}) {
  final sd = math.sin(doc * math.pi / 180);
  final sl = math.sin(lan * math.pi / 180);
  final z = math.sqrt(math.max(0, 1 - sd * sd - sl * sl));
  final nghieng = math.acos(z.clamp(-1.0, 1.0)) * 180 / math.pi;
  var x = lan / gioiHanThuocDo;
  var y = -doc / gioiHanThuocDo;
  final r = math.sqrt(x * x + y * y);
  if (r > 1) {
    x /= r;
    y /= r;
  }
  final canBang = canBangTruoc ? nghieng <= 1.0 : nghieng < 0.5;
  return (x: x, y: y, nghieng: nghieng, canBang: canBang);
}
