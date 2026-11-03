/// Dải cường độ từ trường Trái Đất bình thường ở bề mặt (µT).
const tuTruongThapNhat = 25.0;
const tuTruongCaoNhat = 65.0;

/// Ngưỡng TẮT cảnh báo (hẹp hơn ngưỡng bật - trễ hai ngưỡng chống nhấp nháy):
/// chỉ coi là yên khi về hẳn trong 27-62 µT và lệch mô hình <= 15%.
const tuTruongYenThapNhat = 27.0;
const tuTruongYenCaoNhat = 62.0;
const lechBatPhanTram = 20.0;
const lechYenPhanTram = 15.0;

/// So cường độ đo được với mô hình.
typedef DanhGiaTuTruong = ({
  double doDuoc,

  /// Cường độ theo WMM tại vị trí (µT), null khi chưa có vị trí.
  double? moHinh,

  /// Lệch so mô hình (%), null khi chưa có mô hình.
  double? lechPhanTram,

  /// Ngoài dải 25-65 µT hoặc lệch mô hình > 20%: có nhiễu từ gần máy.
  bool batThuong,

  /// Đủ yên để TẮT cảnh báo đang bật (ngưỡng hẹp hơn [batThuong]). Giữa hai
  /// ngưỡng: không bật mới, không tắt - xem `TreCanhBao`.
  bool yen,
});

/// [moHinhNt] = `TuTruongDiaCau.f` (nT).
DanhGiaTuTruong danhGiaTuTruong(double doDuocUt, {double? moHinhNt}) {
  final mh = moHinhNt == null ? null : moHinhNt / 1000;
  final lech = mh == null || mh <= 0 ? null : (doDuocUt - mh) / mh * 100;
  return (
    doDuoc: doDuocUt,
    moHinh: mh,
    lechPhanTram: lech,
    batThuong:
        doDuocUt < tuTruongThapNhat ||
        doDuocUt > tuTruongCaoNhat ||
        (lech != null && lech.abs() > lechBatPhanTram),
    yen:
        doDuocUt >= tuTruongYenThapNhat &&
        doDuocUt <= tuTruongYenCaoNhat &&
        (lech == null || lech.abs() <= lechYenPhanTram),
  );
}
