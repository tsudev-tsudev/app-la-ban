import 'dart:math' as math;

/// Áp suất mực biển chuẩn ISA (hPa).
const apSuatChuan = 1013.25;

/// Độ cao khí áp (m) theo khí quyển chuẩn quốc tế với áp suất mực biển
/// [apSuatMucBien] (QNH).
double doCaoKhiAp(double apSuat, {double apSuatMucBien = apSuatChuan}) =>
    44330.77 * (1 - math.pow(apSuat / apSuatMucBien, 0.190263));

/// Áp suất mực biển suy ra từ áp suất đo [apSuat] tại độ cao [doCaoM].
double apSuatMucBienTu(double apSuat, double doCaoM) =>
    apSuat / math.pow(1 - doCaoM / 44330.77, 1 / 0.190263);

/// Hiệu chỉnh khí áp kế theo độ cao GPS: khí áp kế đo CHÊNH độ cao rất mịn
/// (~0,1 m) nhưng độ cao tuyệt đối lệch theo thời tiết (±1 hPa ~ ±8 m); GPS
/// cho độ cao tuyệt đối nhưng nhiễu. Mỗi lần có GPS đủ tốt, ước lượng QNH
/// rồi lọc trung bình trượt mũ -> độ cao khí áp vừa mịn vừa đúng mức.
final class BoHieuChinhKhiAp {
  new({this.nguongDoChinhXacM = 15, this.heSo = 0.1});

  /// Chỉ dùng mẫu GPS có độ chính xác dọc tốt hơn ngưỡng này.
  final double nguongDoChinhXacM;
  final double heSo;

  double? _qnh;
  int _soMau = 0;

  /// QNH đang dùng (chuẩn ISA khi chưa có mẫu GPS tốt).
  double get apSuatMucBien => _qnh ?? apSuatChuan;
  bool get daHieuChinh => _qnh != null;

  /// Nạp một cặp áp suất (hPa) + độ cao GPS trên mực biển (m) kèm độ chính
  /// xác dọc (m). Bỏ mẫu kém / thiếu.
  void nap(double? apSuat, double? doCaoMucBien, double? doChinhXacDung) {
    if (apSuat == null ||
        doCaoMucBien == null ||
        doChinhXacDung == null ||
        !apSuat.isFinite ||
        !doCaoMucBien.isFinite ||
        doChinhXacDung > nguongDoChinhXacM) {
      return;
    }
    final q = apSuatMucBienTu(apSuat, doCaoMucBien);
    if (q < 870 || q > 1090) return; // ngoài mọi thời tiết thực - mẫu hỏng
    _soMau++;
    // Vài mẫu đầu lấy trung bình cộng để hội tụ nhanh, sau đó trượt mũ.
    final k = math.max(heSo, 1 / _soMau);
    _qnh = _qnh == null ? q : _qnh! + k * (q - _qnh!);
  }

  /// Độ cao khí áp đã hiệu chỉnh.
  double doCao(double apSuat) =>
      doCaoKhiAp(apSuat, apSuatMucBien: apSuatMucBien);
}
