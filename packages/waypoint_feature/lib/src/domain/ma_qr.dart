import 'dart:convert';
import 'dart:typed_data';

/// Mã QR (ISO/IEC 18004) chế độ byte, mức sửa lỗi M (~15%) - tự viết để
/// không thêm gói ngoài. Đối chiếu từng ô với thư viện `qrcode` (npm) ở test.
final class MaQr {
  new _(this.phienBan, this.mat, this._o);

  /// Phiên bản 1..40.
  final int phienBan;

  /// Mẫu mặt nạ đã chọn 0..7.
  final int mat;

  final List<Uint8List> _o;

  /// Số ô mỗi cạnh (không gồm lề trắng).
  int get canh => _o.length;

  /// Ô (cột [x], hàng [y]) là ô tối.
  bool toi(int x, int y) => _o[y][x] == 1;
}

const _eccMoiKhoi = [
  -1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, //
  26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, //
  28, 28, 28, 28, 28,
];
const _soKhoi = [
  -1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, //
  17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, //
  47, 49,
];

/// Mã [noiDung] (UTF-8). [mat] ép mẫu mặt nạ (test); null = chọn theo điểm
/// phạt. Quá dung lượng phiên bản 40 -> [ArgumentError].
MaQr maHoaQr(String noiDung, {int? mat}) {
  final du = utf8.encode(noiDung);
  var v = 1;
  for (; v <= 40; v++) {
    final demBit = v < 10 ? 8 : 16;
    if (4 + demBit + du.length * 8 <= _soCwDuLieu(v) * 8) break;
  }
  if (v > 40) throw ArgumentError('qr: nội dung quá dài (${du.length} byte)');

  // Chuỗi bit: chế độ byte 0100 · số byte · dữ liệu · kết thúc · đệm.
  final bit = <int>[];
  void them(int giaTri, int n) {
    for (var i = n - 1; i >= 0; i--) {
      bit.add((giaTri >> i) & 1);
    }
  }

  them(4, 4);
  them(du.length, v < 10 ? 8 : 16);
  for (final x in du) {
    them(x, 8);
  }
  final sucChua = _soCwDuLieu(v) * 8;
  them(0, (sucChua - bit.length).clamp(0, 4));
  them(0, (8 - bit.length % 8) % 8);
  for (var dem = 0xEC; bit.length < sucChua; dem ^= 0xEC ^ 0x11) {
    them(dem, 8);
  }
  final cw = Uint8List(bit.length ~/ 8);
  for (var i = 0; i < bit.length; i++) {
    cw[i >> 3] |= bit[i] << (7 - (i & 7));
  }

  final q = _Luoi(v)
    ..veChucNang()
    ..veDuLieu(_xenKe(cw, v));
  var chon = mat;
  if (chon == null) {
    var thapNhat = 1 << 62;
    for (var m = 0; m < 8; m++) {
      q
        ..apMat(m)
        ..veDinhDang(m);
      final p = q.diemPhat();
      if (p < thapNhat) {
        thapNhat = p;
        chon = m;
      }
      q.apMat(m);
    }
  }
  q
    ..apMat(chon!)
    ..veDinhDang(chon);
  return MaQr._(v, chon, q.o);
}

int _soOThoDuLieu(int v) {
  var kq = (16 * v + 128) * v + 64;
  if (v >= 2) {
    final soCanh = v ~/ 7 + 2;
    kq -= (25 * soCanh - 10) * soCanh - 55;
    if (v >= 7) kq -= 36;
  }
  return kq;
}

int _soCwDuLieu(int v) => _soOThoDuLieu(v) ~/ 8 - _eccMoiKhoi[v] * _soKhoi[v];

List<int> _viTriCanh(int v) {
  if (v == 1) return const [];
  final n = v ~/ 7 + 2;
  final buoc = v == 32 ? 26 : (v * 4 + n * 2 + 1) ~/ (n * 2 - 2) * 2;
  final kq = <int>[6];
  for (var p = v * 4 + 17 - 7; kq.length < n; p -= buoc) {
    kq.insert(1, p);
  }
  return kq;
}

// --- Reed-Solomon trên GF(256), đa thức 0x11D ---

int _nhan(int x, int y) {
  var z = 0;
  for (var i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >> 7) * 0x11D);
    z ^= ((y >> i) & 1) * x;
  }
  return z & 0xff;
}

List<int> _sinh(int bac) {
  final kq = List<int>.filled(bac, 0);
  kq[bac - 1] = 1;
  var goc = 1;
  for (var i = 0; i < bac; i++) {
    for (var j = 0; j < bac; j++) {
      kq[j] = _nhan(kq[j], goc);
      if (j + 1 < bac) kq[j] ^= kq[j + 1];
    }
    goc = _nhan(goc, 2);
  }
  return kq;
}

List<int> _du(List<int> duLieu, List<int> sinh) {
  final kq = List<int>.filled(sinh.length, 0);
  for (final b in duLieu) {
    final heSo = b ^ kq[0];
    kq
      ..setRange(0, kq.length - 1, kq, 1)
      ..last = 0;
    for (var i = 0; i < kq.length; i++) {
      kq[i] ^= _nhan(sinh[i], heSo);
    }
  }
  return kq;
}

List<int> _xenKe(Uint8List duLieu, int v) {
  final soKhoi = _soKhoi[v];
  final ecc = _eccMoiKhoi[v];
  final tho = _soOThoDuLieu(v) ~/ 8;
  final soNgan = soKhoi - tho % soKhoi;
  final daiNgan = tho ~/ soKhoi;
  final sinh = _sinh(ecc);
  final khoi = <List<int>>[];
  for (var i = 0, k = 0; i < soKhoi; i++) {
    final n = daiNgan - ecc + (i < soNgan ? 0 : 1);
    final dat = duLieu.sublist(k, k + n).toList();
    k += n;
    final e = _du(dat, sinh);
    if (i < soNgan) dat.add(0);
    khoi.add([...dat, ...e]);
  }
  final kq = <int>[];
  for (var i = 0; i < khoi[0].length; i++) {
    for (var j = 0; j < khoi.length; j++) {
      if (i != daiNgan - ecc || j >= soNgan) kq.add(khoi[j][i]);
    }
  }
  return kq;
}

final class _Luoi {
  new(this.v)
    : n = v * 4 + 17,
      o = List.generate(v * 4 + 17, (_) => Uint8List(v * 4 + 17)),
      cn = List.generate(v * 4 + 17, (_) => Uint8List(v * 4 + 17));

  final int v;
  final int n;
  final List<Uint8List> o;

  /// Ô chức năng (không chứa dữ liệu, không áp mặt nạ).
  final List<Uint8List> cn;

  void _dat(int x, int y, bool toi) {
    o[y][x] = toi ? 1 : 0;
    cn[y][x] = 1;
  }

  void veChucNang() {
    for (var i = 0; i < n; i++) {
      _dat(6, i, i.isEven);
      _dat(i, 6, i.isEven);
    }
    for (final (x, y) in [(3, 3), (n - 4, 3), (3, n - 4)]) {
      for (var dy = -4; dy <= 4; dy++) {
        for (var dx = -4; dx <= 4; dx++) {
          final xx = x + dx;
          final yy = y + dy;
          if (xx < 0 || xx >= n || yy < 0 || yy >= n) continue;
          final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
          _dat(xx, yy, d != 2 && d != 4);
        }
      }
    }
    final vt = _viTriCanh(v);
    final cuoi = vt.length - 1;
    for (var i = 0; i < vt.length; i++) {
      for (var j = 0; j < vt.length; j++) {
        if ((i == 0 && j == 0) ||
            (i == 0 && j == cuoi) ||
            (i == cuoi && j == 0)) {
          continue;
        }
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
            _dat(vt[i] + dx, vt[j] + dy, d != 1);
          }
        }
      }
    }
    // Giữ chỗ vùng định dạng (giá trị thật vẽ sau khi chọn mặt nạ).
    veDinhDang(0);
    if (v >= 7) {
      var r = v;
      for (var i = 0; i < 12; i++) {
        r = (r << 1) ^ ((r >> 11) * 0x1F25);
      }
      final b = v << 12 | r;
      for (var i = 0; i < 18; i++) {
        final toi = (b >> i) & 1 == 1;
        final a = n - 11 + i % 3;
        final c = i ~/ 3;
        _dat(a, c, toi);
        _dat(c, a, toi);
      }
    }
  }

  void veDinhDang(int mat) {
    // Mức M = 00.
    final duLieu = mat;
    var r = duLieu;
    for (var i = 0; i < 10; i++) {
      r = (r << 1) ^ ((r >> 9) * 0x537);
    }
    final b = (duLieu << 10 | r) ^ 0x5412;
    bool bit(int i) => (b >> i) & 1 == 1;
    for (var i = 0; i <= 5; i++) {
      _dat(8, i, bit(i));
    }
    _dat(8, 7, bit(6));
    _dat(8, 8, bit(7));
    _dat(7, 8, bit(8));
    for (var i = 9; i < 15; i++) {
      _dat(14 - i, 8, bit(i));
    }
    for (var i = 0; i < 8; i++) {
      _dat(n - 1 - i, 8, bit(i));
    }
    for (var i = 8; i < 15; i++) {
      _dat(8, n - 15 + i, bit(i));
    }
    _dat(8, n - 8, true);
  }

  void veDuLieu(List<int> cw) {
    var i = 0;
    for (var phai = n - 1; phai >= 1; phai -= 2) {
      if (phai == 6) phai = 5;
      for (var doc = 0; doc < n; doc++) {
        for (var j = 0; j < 2; j++) {
          final x = phai - j;
          final len = ((phai + 1) & 2) == 0;
          final y = len ? n - 1 - doc : doc;
          if (cn[y][x] == 0 && i < cw.length * 8) {
            o[y][x] = (cw[i >> 3] >> (7 - (i & 7))) & 1;
            i++;
          }
        }
      }
    }
  }

  void apMat(int m) {
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (cn[y][x] == 1) continue;
        final dao = switch (m) {
          0 => (x + y).isEven,
          1 => y.isEven,
          2 => x % 3 == 0,
          3 => (x + y) % 3 == 0,
          4 => (x ~/ 3 + y ~/ 2).isEven,
          5 => x * y % 2 + x * y % 3 == 0,
          6 => (x * y % 2 + x * y % 3).isEven,
          _ => ((x + y) % 2 + x * y % 3).isEven,
        };
        if (dao) o[y][x] ^= 1;
      }
    }
  }

  /// Điểm phạt 4 luật (N1=3, N2=3, N3=40, N4=10) - cùng cách tính với thư
  /// viện `qrcode` (npm) để chọn cùng mặt nạ.
  int diemPhat() {
    var p = 0;
    for (var a = 0; a < n; a++) {
      var demH = 0;
      var demC = 0;
      int? truocH;
      int? truocC;
      for (var b = 0; b < n; b++) {
        final h = o[a][b];
        if (h == truocH) {
          demH++;
        } else {
          if (demH >= 5) p += 3 + demH - 5;
          truocH = h;
          demH = 1;
        }
        final c = o[b][a];
        if (c == truocC) {
          demC++;
        } else {
          if (demC >= 5) p += 3 + demC - 5;
          truocC = c;
          demC = 1;
        }
      }
      if (demH >= 5) p += 3 + demH - 5;
      if (demC >= 5) p += 3 + demC - 5;
    }
    var khoi = 0;
    for (var y = 0; y < n - 1; y++) {
      for (var x = 0; x < n - 1; x++) {
        final t = o[y][x] + o[y][x + 1] + o[y + 1][x] + o[y + 1][x + 1];
        if (t == 4 || t == 0) khoi++;
      }
    }
    p += khoi * 3;
    var mau = 0;
    for (var a = 0; a < n; a++) {
      var bh = 0;
      var bc = 0;
      for (var b = 0; b < n; b++) {
        bh = ((bh << 1) & 0x7FF) | o[a][b];
        if (b >= 10 && (bh == 0x5D0 || bh == 0x05D)) mau++;
        bc = ((bc << 1) & 0x7FF) | o[b][a];
        if (b >= 10 && (bc == 0x5D0 || bc == 0x05D)) mau++;
      }
    }
    p += mau * 40;
    var toi = 0;
    for (final h in o) {
      for (final x in h) {
        toi += x;
      }
    }
    final k = ((toi * 100 / (n * n)) / 5).ceil() - 10;
    return p + k.abs() * 10;
  }
}
