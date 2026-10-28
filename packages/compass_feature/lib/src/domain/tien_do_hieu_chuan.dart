import 'package:sensors/sensors.dart';

/// Theo dõi luồng hiệu chuẩn hình số 8: máy phải quét đủ các hướng (8 cung
/// phương vị) và các tư thế nghiêng (ngóc lên / cúi xuống / nghiêng trái /
/// phải) để hệ điều hành ước lượng lại độ lệch từ kế. Hàm thuần, thời gian
/// lấy từ `tNs` của mẫu.
final class TienDoHieuChuan {
  new({this.nguongNghieng = 25, this.giuCaoNs = 1500000000});

  /// Góc ngóc / nghiêng (độ) tính là đã quét tư thế nghiêng.
  final double nguongNghieng;

  /// Giữ mức tin cậy cao liên tục bấy lâu thì coi như xong sớm.
  final int giuCaoNs;

  static const _soCung = 8;

  /// Tổng ô cần phủ: 8 cung phương vị + 4 tư thế nghiêng.
  static const int tongO = _soCung + 4;

  final List<bool> _cung = List<bool>.filled(_soCung, false);
  final List<bool> _nghieng = List<bool>.filled(4, false);
  int? _batDauCaoNs;
  var _mucCaoDu = false;

  /// Số ô đã phủ.
  int get daPhu =>
      _cung.where((x) => x).length + _nghieng.where((x) => x).length;

  /// Tiến độ [0, 1].
  double get tiLe => daPhu / tongO;

  /// Xong khi phủ hết, hoặc mức tin cậy cao ổn định sau khi đã phủ >= nửa.
  bool get xong => daPhu == tongO || (_mucCaoDu && daPhu * 2 >= tongO);

  void nap(HuongDoc h) {
    _cung[huongChinh(h.phuongVi).index] = true;
    if (h.doc >= nguongNghieng) _nghieng[0] = true;
    if (h.doc <= -nguongNghieng) _nghieng[1] = true;
    if (h.lan >= nguongNghieng) _nghieng[2] = true;
    if (h.lan <= -nguongNghieng) _nghieng[3] = true;
    final cao = h.muc == MucTinCay.cao && !h.nhieuTu && !h.canHieuChuan;
    if (!cao) {
      _batDauCaoNs = null;
      return;
    }
    final bd = _batDauCaoNs ??= h.tNs;
    if (h.tNs - bd >= giuCaoNs) _mucCaoDu = true;
  }
}
