import 'package:sensors/sensors.dart';

/// Phát hiện lúc kim đi qua một mốc (mặc định 8 hướng chính, mỗi 45°) để
/// rung nhẹ. Có trễ [treDo]: phải vượt qua ranh giới cung ít nhất [treDo] mới
/// tính là sang cung mới, nên rung không lặp khi kim run quanh ranh giới.
final class BoRungMoc {
  new({this.buocDo = 45, this.treDo = 3});

  final double buocDo;
  final double treDo;
  int? _cung;

  /// Nạp phương vị mới; trả chỉ số mốc vừa đi qua (0 = Bắc) hoặc null.
  /// Mẫu đầu tiên chỉ ghi nhận vị trí, không rung.
  int? nap(double phuongVi) {
    final d = chuanHoaDo(phuongVi);
    final soCung = (360 / buocDo).round();
    // Cung k phủ [k*buoc - buoc/2, k*buoc + buoc/2): mốc k ở giữa cung.
    final moi = ((d + buocDo / 2) ~/ buocDo) % soCung;
    final cu = _cung;
    if (cu == null) {
      _cung = moi;
      return null;
    }
    if (moi == cu) return null;
    // Khoảng cách tới tâm cung cũ phải vượt nửa cung + trễ.
    final xa = hieuGoc(d, cu * buocDo).abs();
    if (xa < buocDo / 2 + treDo) return null;
    _cung = moi;
    return moi;
  }

  void datLai() => _cung = null;
}
