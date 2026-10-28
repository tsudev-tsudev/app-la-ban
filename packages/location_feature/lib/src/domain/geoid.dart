import 'dart:typed_data';

/// Lưới độ cao geoid EGM96 1° (asset `geoid_egm96_1do.bin`, sinh bằng
/// `tools/build/geoid.py`): đổi độ cao GPS trên elipxoit WGS84 sang độ cao
/// trên mực nước biển khi máy không trả sẵn (Android < 14).
final class LuoiGeoid {
  new _(this._dm);

  /// Đọc asset: "LBGE" + u16 phiên bản + 181 x 360 int16 (dm), hàng vĩ độ
  /// 90 -> -90, cột kinh độ -180 -> 179.
  factory LuoiGeoid.tuBytes(ByteData b) {
    const soO = 181 * 360;
    if (b.lengthInBytes != 6 + soO * 2 ||
        String.fromCharCodes(b.buffer.asUint8List(b.offsetInBytes, 4)) !=
            'LBGE') {
      throw const FormatException('geoid: sai định dạng');
    }
    final dm = Int16List(soO);
    for (var i = 0; i < soO; i++) {
      dm[i] = b.getInt16(6 + i * 2, Endian.little);
    }
    return LuoiGeoid._(dm);
  }

  final Int16List _dm;

  double _o(int hang, int cot) => _dm[hang * 360 + cot % 360] / 10;

  /// Độ cao geoid N (m) tại điểm - nội suy song tuyến.
  double doCao(double viDo, double kinhDo) {
    final y = (90 - viDo.clamp(-90.0, 90.0)).toDouble();
    final x = ((kinhDo + 180) % 360 + 360) % 360;
    final h0 = y.floor().clamp(0, 179);
    final c0 = x.floor();
    final fy = y - h0;
    final fx = x - c0;
    final tren = _o(h0, c0) * (1 - fx) + _o(h0, c0 + 1) * fx;
    final duoi = _o(h0 + 1, c0) * (1 - fx) + _o(h0 + 1, c0 + 1) * fx;
    return tren * (1 - fy) + duoi * fy;
  }

  /// Độ cao trên mực nước biển = độ cao elipxoit - N.
  double doCaoMucBien(double viDo, double kinhDo, double doCaoElip) =>
      doCaoElip - doCao(viDo, kinhDo);
}
