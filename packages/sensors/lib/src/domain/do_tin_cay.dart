/// Mức tin cậy hướng hiển thị cho người dùng (Spec §4.1: High/Medium/Low).
enum MucTinCay { cao, trungBinh, thap }

/// Độ chính xác hệ điều hành báo cho cảm biến từ
/// (`SensorManager.SENSOR_STATUS_*`): 0 không tin cậy ... 3 cao.
enum DoChinhXacOs { khongTinCay, thap, trungBinh, cao }

/// Đánh giá tin cậy của một thời điểm.
typedef DanhGiaTinCay = ({
  MucTinCay muc,

  /// Từ trường lệch hẳn khỏi dải Trái Đất hoặc vừa đổi đột ngột (gần nam
  /// châm, sắt thép, loa...).
  bool nhieuTu,

  /// Nên hiện hướng dẫn hiệu chuẩn hình số 8.
  bool canHieuChuan,
});

/// Từ trường Trái Đất ở bề mặt khoảng 22-67 µT; nới biên cho sai số cảm biến.
const tuTraiDatMin = 18.0;
const tuTraiDatMax = 75.0;

/// Theo dõi cường độ từ trường để phát hiện nhiễu: so mỗi mẫu với đường nền
/// trượt chậm (EMA). Đường nền chỉ học khi cường độ nằm trong dải Trái Đất.
final class TheoDoiNhieuTu {
  new({this.heSoNen = 0.01, this.nguongLech = 0.2});

  /// Hệ số EMA cập nhật đường nền mỗi mẫu.
  final double heSoNen;

  /// Lệch tương đối so với nền coi là nhiễu (0,2 = 20%).
  final double nguongLech;

  double? _nen;

  double? get nen => _nen;

  void datLai() => _nen = null;

  /// Nạp cường độ [uT]; trả true nếu mẫu này bị coi là nhiễu.
  bool nap(double uT) {
    final ngoaiDai = uT < tuTraiDatMin || uT > tuTraiDatMax;
    final n = _nen;
    if (n == null) {
      if (!ngoaiDai) _nen = uT;
      return ngoaiDai;
    }
    final lech = (uT - n).abs() / n > nguongLech;
    if (!ngoaiDai && !lech) _nen = n + heSoNen * (uT - n);
    return ngoaiDai || lech;
  }
}

/// Gộp tín hiệu thành mức tin cậy: độ chính xác OS của cảm biến từ, nhiễu
/// từ, độ rung hướng (độ lệch chuẩn vòng khi máy đứng yên, độ).
DanhGiaTinCay danhGiaTinCay({
  required DoChinhXacOs os,
  required bool nhieuTu,
  double? doLechChuan,
}) {
  var bac = switch (os) {
    DoChinhXacOs.cao => 2,
    DoChinhXacOs.trungBinh => 1,
    DoChinhXacOs.thap || DoChinhXacOs.khongTinCay => 0,
  };
  if (nhieuTu) bac = 0;
  if (doLechChuan != null && doLechChuan > 5 && bac > 0) bac--;
  final muc = [MucTinCay.thap, MucTinCay.trungBinh, MucTinCay.cao][bac];
  return (
    muc: muc,
    nhieuTu: nhieuTu,
    canHieuChuan:
        muc == MucTinCay.thap && !nhieuTu || os == DoChinhXacOs.khongTinCay,
  );
}

/// Phát hiện máy đứng yên từ con quay để hạ tần số lấy mẫu (tiết kiệm pin):
/// đứng yên khi |ω| < [nguong] rad/s liên tục >= [thoiGian] giây, chuyển
/// động lại ngay khi vượt [nguong] x 3.
final class PhatHienDungYen {
  new({this.nguong = 0.03, this.thoiGian = 3});

  final double nguong;
  final double thoiGian;

  var _yen = 0.0;
  var _dungYen = false;

  bool get dungYen => _dungYen;

  /// Nạp độ lớn tốc độ góc [omega] (rad/s) sau [dt] giây. Trả true nếu trạng
  /// thái vừa đổi.
  bool nap(double omega, double dt) {
    final cu = _dungYen;
    if (omega < nguong) {
      _yen += dt;
      if (_yen >= thoiGian) _dungYen = true;
    } else {
      _yen = 0;
      if (omega > nguong * 3) _dungYen = false;
    }
    return cu != _dungYen;
  }
}
