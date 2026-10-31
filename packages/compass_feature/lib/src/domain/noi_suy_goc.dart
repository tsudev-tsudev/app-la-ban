import 'package:sensors/sensors.dart';

/// Nội suy phương vị giữa hai lô cảm biến để mặt số xoay theo từng vsync.
///
/// Lô hướng tới ~45-60 lần/giây, màn 90 / 120 Hz vẽ nhanh hơn: không nội suy
/// thì mặt số chỉ đổi mỗi 2-3 vsync (đo trên Galaxy M32 90 Hz: ~45 FPS). Mỗi
/// đích mới, mặt số đi thẳng (đường ngắn nhất qua 0°) từ góc đang hiện tới
/// đích trong đúng một [khoangUs] - khoảng cách trung bình giữa các lô - nên
/// trễ thêm tối đa một khoảng lô.
final class BoNoiSuyGoc {
  new({
    this.khoangMacDinhUs = 16000,
    this.khoangMinUs = 8000,
    this.khoangMaxUs = 50000,
    this.ngatUs = 100000,
    this.heSoKeo = 1.25,
  });

  /// Khoảng ước lượng ban đầu / sau khi luồng ngắt.
  final int khoangMacDinhUs;
  final int khoangMinUs;
  final int khoangMaxUs;

  /// Hai đích cách nhau hơn mức này coi như luồng ngắt (máy đứng yên hạ tần
  /// số, tab ẩn): không đưa vào ước lượng khoảng.
  final int ngatUs;

  /// Thời gian đi tới đích = [khoangUs] x hệ số này. Lô đến không đều; đi
  /// đúng bằng khoảng trung bình thì nửa số lần tới đích trước lô kế tiếp,
  /// mặt số khựng một nhịp (đo trên M32: 1,65% khung). Kéo dài 25% đổi lấy
  /// ~4 ms trễ.
  final double heSoKeo;

  double? _tu;
  double _den = 0;

  /// Mốc bắt đầu nội suy tới [_den].
  int _t0 = 0;

  /// Lúc đích trước tới (đo nhịp lô).
  int _tTruoc = 0;
  double _khoang = 0;

  /// Khoảng nội suy hiện tại (µs).
  double get khoangUs => _khoang;

  /// Nạp đích mới tại thời điểm [tUs]. Đích đầu tiên hiện ngay.
  void dat(double den, int tUs) {
    if (_tu == null) {
      _tu = chuanHoaDo(den);
      _den = _tu!;
      _khoang = khoangMacDinhUs.toDouble();
      _t0 = tUs - (_khoang * heSoKeo).ceil();
      _tTruoc = tUs;
      return;
    }
    // Góc đang hiện tính theo khoảng CŨ, trước khi cập nhật khoảng.
    _tu = giaTri(tUs);
    _den = chuanHoaDo(den);
    _t0 = tUs;
    final cach = tUs - _tTruoc;
    _tTruoc = tUs;
    if (cach > ngatUs || cach <= 0) {
      _khoang = khoangMacDinhUs.toDouble();
    } else {
      // Trung bình trượt: một lô đến sớm / muộn không làm giật nhịp.
      _khoang = (_khoang * 0.8 + cach * 0.2).clamp(
        khoangMinUs.toDouble(),
        khoangMaxUs.toDouble(),
      );
    }
  }

  /// Đặt góc tới [den] NGAY tại [tUs], không nội suy (Reduce motion - A8b).
  /// Nhịp lô vẫn được đo để tắt Reduce motion giữa chừng nội suy tiếp mượt.
  void nhay(double den, int tUs) {
    dat(den, tUs);
    _tu = _den;
  }

  /// Góc hiện tại [0, 360) tại [tUs].
  double giaTri(int tUs) {
    final tu = _tu;
    if (tu == null) return 0;
    return chuanHoaDo(tu + hieuGoc(_den, tu) * _tiLe(tUs));
  }

  /// Đã tới đích (dừng vẽ lại cho tới đích sau).
  bool xong(int tUs) => _tu == null || _tiLe(tUs) >= 1;

  double _tiLe(int tUs) => ((tUs - _t0) / (_khoang * heSoKeo)).clamp(0.0, 1.0);
}
