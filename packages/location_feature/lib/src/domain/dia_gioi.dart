import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Kết quả tra địa giới hành chính Việt Nam.
@immutable
final class DiaGioi {
  const new({
    required this.maTinh,
    required this.tinh,
    required this.tinhEn,
    this.xa,
    this.xaEn,
  });

  /// Mã ISO 3166-2 (VN-HN, VN-34...).
  final String maTinh;
  final String tinh;
  final String tinhEn;

  /// Xã / phường / đặc khu; null khi điểm rơi vào khe giữa các xã (thường
  /// là biển ven bờ).
  final String? xa;
  final String? xaEn;

  /// Tên theo ngôn ngữ: tiếng Anh thiếu thì dùng tên tiếng Việt.
  String tenTinh({required bool tiengViet}) =>
      tiengViet || tinhEn.isEmpty ? tinh : tinhEn;

  String? tenXa({required bool tiengViet}) =>
      tiengViet || (xaEn ?? '').isEmpty ? xa : xaEn;

  @override
  bool operator ==(Object other) =>
      other is DiaGioi && other.maTinh == maTinh && other.xa == xa;

  @override
  int get hashCode => Object.hash(maTinh, xa);
}

final class _Vung {
  new(this.ten, this.tenEn, this.hop, this.viTriHinh);

  final String ten;
  final String tenEn;

  /// Hộp bao (x0, y0, x1, y1) đơn vị 1e-5 độ.
  final Int32List hop;

  /// Vị trí bắt đầu phần hình trong bộ đệm - giải mã lười khi tra.
  final int viTriHinh;

  bool trongHop(int x, int y) =>
      x >= hop[0] && x <= hop[2] && y >= hop[1] && y <= hop[3];
}

final class _Tinh {
  new(this.ma, this.vung, this.xa);

  final String ma;
  final _Vung vung;
  final List<_Vung> xa;
}

const _luongTu = 100000;

/// Bộ đọc asset `dia_gioi_vn.bin` (sinh bằng `tools/build/dia-gioi.py`, dữ
/// liệu © OpenStreetMap contributors, ODbL). Chỉ giải mã phần đầu (tên, hộp
/// bao); hình giải mã lười khi điểm rơi vào hộp - tốn ~2 MB RAM.
///
/// Định dạng: "LBDG" u16 phiên bản, u16 số tỉnh, chuỗi nguồn; mỗi tỉnh: chuỗi
/// mã, tên, tên en, hộp bao 4 x i32, hình, varint số xã, mỗi xã: tên, tên en,
/// hộp, hình. Chuỗi = varint độ dài + UTF-8. Hình = varint số vòng, mỗi vòng
/// varint số điểm rồi các cặp (x, y) zigzag varint hiệu với điểm trước.
final class BanDoDiaGioi {
  new _(this._b, this.nguon, this._tinh);

  factory BanDoDiaGioi.tuBytes(Uint8List b) {
    if (b.length < 8 || ascii.decode(b.sublist(0, 4)) != 'LBDG') {
      throw const FormatException('địa giới: sai định dạng');
    }
    final bd = ByteData.sublistView(b);
    if (bd.getUint16(4, Endian.little) != 1) {
      throw const FormatException('địa giới: phiên bản lạ');
    }
    final soTinh = bd.getUint16(6, Endian.little);
    final d = _Doc(b, 8);
    final nguon = d.chuoi();
    final tinh = <_Tinh>[];
    for (var i = 0; i < soTinh; i++) {
      final ma = d.chuoi();
      final v = d.vung();
      final soXa = d.varint();
      tinh.add(_Tinh(ma, v, [for (var j = 0; j < soXa; j++) d.vung()]));
    }
    return BanDoDiaGioi._(b, nguon, tinh);
  }

  final Uint8List _b;

  /// Ghi nguồn dữ liệu, ví dụ "OpenStreetMap 2026-10-27".
  final String nguon;
  final List<_Tinh> _tinh;

  int get soTinh => _tinh.length;
  int get soXa => _tinh.fold(0, (s, t) => s + t.xa.length);

  bool _chua(_Vung v, int x, int y) =>
      v.trongHop(x, y) && _Doc(_b, v.viTriHinh).chuaDiem(x, y);

  /// Tra điểm; null khi ngoài lãnh thổ (kể cả lãnh hải) Việt Nam.
  DiaGioi? tra(double viDo, double kinhDo) {
    final x = (kinhDo * _luongTu).round();
    final y = (viDo * _luongTu).round();
    for (final t in _tinh) {
      if (!_chua(t.vung, x, y)) continue;
      for (final xa in t.xa) {
        if (_chua(xa, x, y)) {
          return DiaGioi(
            maTinh: t.ma,
            tinh: t.vung.ten,
            tinhEn: t.vung.tenEn,
            xa: xa.ten,
            xaEn: xa.tenEn,
          );
        }
      }
      return DiaGioi(maTinh: t.ma, tinh: t.vung.ten, tinhEn: t.vung.tenEn);
    }
    return null;
  }
}

final class _Doc {
  new(this._b, this._i);

  final Uint8List _b;
  int _i;

  int varint() {
    var kq = 0, dich = 0;
    while (true) {
      final c = _b[_i++];
      kq |= (c & 0x7f) << dich;
      if (c < 0x80) return kq;
      dich += 7;
    }
  }

  int zigzag() {
    final v = varint();
    return (v >> 1) ^ -(v & 1);
  }

  String chuoi() {
    final n = varint();
    final s = utf8.decode(Uint8List.sublistView(_b, _i, _i + n));
    _i += n;
    return s;
  }

  Int32List _hop() {
    final bd = ByteData.sublistView(_b, _i, _i + 16);
    _i += 16;
    return Int32List.fromList([
      for (var k = 0; k < 4; k++) bd.getInt32(k * 4, Endian.little),
    ]);
  }

  void _boQuaHinh() {
    final soVong = varint();
    for (var v = 0; v < soVong; v++) {
      final soDiem = varint();
      for (var k = 0; k < 2 * soDiem; k++) {
        while (_b[_i++] >= 0x80) {}
      }
    }
  }

  _Vung vung() {
    final ten = chuoi();
    final tenEn = chuoi();
    final hop = _hop();
    final vt = _i;
    _boQuaHinh();
    return _Vung(ten, tenEn, hop, vt);
  }

  /// Quy tắc chẵn-lẻ trên mọi vòng (lỗ và đảo tự đúng), giải mã từng điểm
  /// không cấp phát.
  bool chuaDiem(int px, int py) {
    var trong = false;
    final soVong = varint();
    for (var v = 0; v < soVong; v++) {
      final n = varint();
      if (n == 0) continue;
      final x0 = zigzag(), y0 = zigzag();
      var xa = x0, ya = y0;
      for (var k = 1; k <= n; k++) {
        int xb, yb;
        if (k < n) {
          xb = xa + zigzag();
          yb = ya + zigzag();
        } else {
          xb = x0;
          yb = y0;
        }
        if ((ya > py) != (yb > py) &&
            px < (xb - xa) * (py - ya) / (yb - ya) + xa) {
          trong = !trong;
        }
        xa = xb;
        ya = yb;
      }
    }
    return trong;
  }
}
