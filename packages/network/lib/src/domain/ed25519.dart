import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// Kiểm chữ ký Ed25519 (RFC 8032 mục 5.1.7) thuần Dart bằng BigInt - chỉ để
// kiểm Remote Config ký số (vài lần / ngày), không cần nhanh. Tự viết thay vì
// thêm gói mật mã bên thứ ba (CLAUDE.md: không thêm SDK ngoài QUYET_DINH).
// Không có khoá bí mật ở app nên không cần chống kênh kề thời gian.

final BigInt _p = (BigInt.one << 255) - BigInt.from(19);
final BigInt _l =
    (BigInt.one << 252) +
    BigInt.parse('27742317777372353535851937790883648493');
final BigInt _d =
    (-BigInt.from(121665) * BigInt.from(121666).modInverse(_p)) % _p;

/// Căn bậc hai của -1 mod p.
final BigInt _canAm1 = BigInt.two.modPow((_p - BigInt.one) >> 2, _p);

/// Điểm toạ độ mở rộng (X, Y, Z, T), x = X/Z, y = Y/Z, x*y = T/Z.
typedef _Diem = (BigInt, BigInt, BigInt, BigInt);

final _Diem _khong = (BigInt.zero, BigInt.one, BigInt.one, BigInt.zero);

final _Diem _g = () {
  final y = (BigInt.from(4) * BigInt.from(5).modInverse(_p)) % _p;
  final x = _timX(y, 0)!;
  return (x, y, BigInt.one, (x * y) % _p);
}();

_Diem _cong(_Diem p, _Diem q) {
  final a = ((p.$2 - p.$1) * (q.$2 - q.$1)) % _p;
  final b = ((p.$2 + p.$1) * (q.$2 + q.$1)) % _p;
  final c = (BigInt.two * p.$4 * q.$4 * _d) % _p;
  final d = (BigInt.two * p.$3 * q.$3) % _p;
  final e = b - a;
  final f = d - c;
  final g = d + c;
  final h = b + a;
  return ((e * f) % _p, (g * h) % _p, (f * g) % _p, (e * h) % _p);
}

_Diem _nhan(BigInt s, _Diem p) {
  var q = _khong;
  var r = p;
  var k = s;
  while (k > BigInt.zero) {
    if (k.isOdd) q = _cong(q, r);
    r = _cong(r, r);
    k >>= 1;
  }
  return q;
}

bool _bang(_Diem p, _Diem q) =>
    (p.$1 * q.$3 - q.$1 * p.$3) % _p == BigInt.zero &&
    (p.$2 * q.$3 - q.$2 * p.$3) % _p == BigInt.zero;

BigInt? _timX(BigInt y, int dau) {
  if (y >= _p) return null;
  final x2 =
      ((y * y - BigInt.one) * (_d * y * y + BigInt.one).modInverse(_p)) % _p;
  if (x2 == BigInt.zero) return dau == 1 ? null : BigInt.zero;
  var x = x2.modPow((_p + BigInt.from(3)) >> 3, _p);
  if ((x * x - x2) % _p != BigInt.zero) x = (x * _canAm1) % _p;
  if ((x * x - x2) % _p != BigInt.zero) return null;
  if ((x.isOdd ? 1 : 0) != dau) x = _p - x;
  return x;
}

BigInt _soLittle(List<int> b) {
  var n = BigInt.zero;
  for (var i = b.length - 1; i >= 0; i--) {
    n = (n << 8) | BigInt.from(b[i]);
  }
  return n;
}

_Diem? _giaiNen(List<int> b) {
  if (b.length != 32) return null;
  var y = _soLittle(b);
  final dau = (y >> 255).toInt();
  y &= (BigInt.one << 255) - BigInt.one;
  final x = _timX(y, dau);
  if (x == null) return null;
  return (x, y, BigInt.one, (x * y) % _p);
}

/// Chữ ký [chuKy] (64 byte) của khoá công khai [khoa] (32 byte) trên
/// [thongDiep] có hợp lệ không. Sai độ dài / điểm không hợp lệ -> false.
bool kiemEd25519(List<int> khoa, List<int> thongDiep, List<int> chuKy) {
  if (khoa.length != 32 || chuKy.length != 64) return false;
  final a = _giaiNen(khoa);
  if (a == null) return false;
  final rByte = chuKy.sublist(0, 32);
  final r = _giaiNen(rByte);
  if (r == null) return false;
  final s = _soLittle(chuKy.sublist(32));
  if (s >= _l) return false;
  final bam = sha512.convert(
    Uint8List.fromList([...rByte, ...khoa, ...thongDiep]),
  );
  final h = _soLittle(bam.bytes) % _l;
  return _bang(_nhan(s, _g), _cong(r, _nhan(h, a)));
}
