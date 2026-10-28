import 'dart:typed_data';

/// Loại mẫu trong lô gửi từ nền tảng. Giá trị [ma] là hợp đồng với mã
/// native (`CamBienPlugin.kt`) - KHÔNG đổi số đã dùng.
enum LoaiMau {
  /// `TYPE_ROTATION_VECTOR`: x, y, z, w (quaternion máy -> ENU).
  xoayVector(0),

  /// `TYPE_GAME_ROTATION_VECTOR` (không dùng từ trường).
  xoayGame(1),

  /// `TYPE_MAGNETIC_FIELD` (µT, đã hiệu chuẩn sắt cứng bởi OS).
  tu(2),

  /// `TYPE_ACCELEROMETER` (m/s²).
  giaToc(3),

  /// `TYPE_GYROSCOPE` (rad/s).
  conQuay(4),

  /// `TYPE_PRESSURE` (hPa) ở x.
  apSuat(5),

  /// Hướng màn hình đổi: x = 0..3 (`Display.getRotation`).
  xoayManHinh(6);

  new(this.ma);

  final int ma;

  static final Map<int, LoaiMau> _theoMa = {for (final l in values) l.ma: l};
}

/// Một mẫu cảm biến. [tNs]: mốc thời gian ns (đồng hồ khởi động máy).
final class MauCamBien {
  const new(
    this.loai,
    this.tNs, {
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.w,
    this.doChinhXac = 3,
  });

  final LoaiMau loai;
  final int tNs;
  final double x;
  final double y;
  final double z;
  final double? w;

  /// 0..3 như `SensorManager.SENSOR_STATUS_*`.
  final int doChinhXac;

  @override
  String toString() => 'MauCamBien(${loai.name}, $tNs, $x, $y, $z, $w)';
}

/// Số double mỗi mẫu trong lô:
/// [loai, tNs, x, y, z, w (NaN = không có), độ chính xác].
const soTruongMoiMau = 7;

/// Giải mã lô phẳng từ nền tảng. Bỏ qua mẫu loại lạ / phần dư cuối lô.
List<MauCamBien> giaiMaLo(Float64List lo) {
  final kq = <MauCamBien>[];
  for (var i = 0; i + soTruongMoiMau <= lo.length; i += soTruongMoiMau) {
    final loai = LoaiMau._theoMa[lo[i].toInt()];
    if (loai == null) continue;
    final w = lo[i + 5];
    kq.add(
      MauCamBien(
        loai,
        lo[i + 1].toInt(),
        x: lo[i + 2],
        y: lo[i + 3],
        z: lo[i + 4],
        w: w.isNaN ? null : w,
        doChinhXac: lo[i + 6].toInt().clamp(0, 3),
      ),
    );
  }
  return kq;
}

/// Mã hoá ngược [giaiMaLo] (dùng cho nguồn giả lập / dữ liệu ghi sẵn).
Float64List maHoaLo(Iterable<MauCamBien> ds) {
  final l = ds.toList();
  final lo = Float64List(l.length * soTruongMoiMau);
  for (var i = 0; i < l.length; i++) {
    final m = l[i];
    final o = i * soTruongMoiMau;
    lo
      ..[o] = m.loai.ma.toDouble()
      ..[o + 1] = m.tNs.toDouble()
      ..[o + 2] = m.x
      ..[o + 3] = m.y
      ..[o + 4] = m.z
      ..[o + 5] = m.w ?? double.nan
      ..[o + 6] = m.doChinhXac.toDouble();
  }
  return lo;
}

/// Cảm biến thiết bị có (trả từ nền tảng).
typedef KhaNangCamBien = ({
  bool xoayVector,
  bool xoayGame,
  bool tu,
  bool giaToc,
  bool conQuay,
  bool apSuat,
});

/// Đọc bảng khả năng từ map của platform channel (khoá = tên [LoaiMau]).
KhaNangCamBien khaNangTuMap(Map<Object?, Object?> m) {
  bool co(LoaiMau l) => m[l.name] == true;
  return (
    xoayVector: co(LoaiMau.xoayVector),
    xoayGame: co(LoaiMau.xoayGame),
    tu: co(LoaiMau.tu),
    giaToc: co(LoaiMau.giaToc),
    conQuay: co(LoaiMau.conQuay),
    apSuat: co(LoaiMau.apSuat),
  );
}
