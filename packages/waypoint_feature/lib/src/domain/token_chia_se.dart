import 'dart:convert';
import 'dart:typed_data';

import 'package:waypoint_feature/src/domain/diem_moc.dart';

/// Gốc link chia sẻ - App Links (assetlinks.json trên landing) mở thẳng app;
/// máy chưa cài app thấy trang xem điểm trên landing.
const gocLinkChiaSe = 'https://compass.tsudev.com/w/';

/// Ghi chú trong link bị cắt còn chừng này ký tự (giữ QR đủ thưa để quét).
const ghiChuChiaSeToiDa = 140;

const _phienBan = 1;

/// Điểm nhận được từ link chia sẻ.
typedef DiemChiaSe = ({
  String ten,
  double viDo,
  double kinhDo,
  double? caoDo,
  String ghiChu,

  /// Hạn link, giây UNIX (UTC).
  int hetHan,
});

/// Lý do link không dùng được.
enum LoiToken {
  /// Không giải mã được / hỏng (bị cắt khi dán, sai CRC).
  hong,

  /// Link của bản app mới hơn.
  phienBanLa,

  /// Đã quá hạn.
  hetHan,
}

/// Ngoại lệ khi đọc token.
final class NgoaiLeToken implements Exception {
  const new(this.loi);

  final LoiToken loi;

  @override
  String toString() => 'NgoaiLeToken(${loi.name})';
}

/// Token TỰ CHỨA (không cần server): phiên bản · cờ · vĩ độ / kinh độ 1e-7°
/// (~1 cm) · hạn (giây) · [cao độ dm] · tên · [ghi chú] · CRC-32, mã
/// base64url không đệm. KHÔNG ký: ai cũng tạo được token cho điểm bất kỳ
/// (giống tự gõ toạ độ) - nội dung luôn coi là dữ liệu không tin cậy, chỉ
/// hiển thị dạng chữ; hạn là tiện ích riêng tư, không phải ranh giới bảo
/// mật.
String maHoaToken(DiemMoc d, {required int hetHan}) {
  final ghi = catChuoi(d.ghiChu.trim(), ghiChuChiaSeToiDa);
  final b = BytesBuilder()
    ..addByte(_phienBan)
    ..addByte((d.caoDo != null ? 1 : 0) | (ghi.isNotEmpty ? 2 : 0))
    ..add(_i32((d.viDo * 1e7).round()))
    ..add(_i32((d.kinhDo * 1e7).round()))
    ..add(_i32(hetHan));
  if (d.caoDo != null) b.add(_i32((d.caoDo! * 10).round()));
  _chuoi(b, catChuoi(d.ten.trim(), tenToiDa));
  if (ghi.isNotEmpty) _chuoi(b, ghi);
  final than = b.toBytes();
  final day = BytesBuilder()
    ..add(than)
    ..add(_i32(crc32(than)));
  return base64Url.encode(day.toBytes()).replaceAll('=', '');
}

/// Link đầy đủ cho [d].
String linkChiaSe(DiemMoc d, {required int hetHan}) =>
    '$gocLinkChiaSe${maHoaToken(d, hetHan: hetHan)}';

/// Đọc token; [bayGio] giây UNIX. Lỗi -> [NgoaiLeToken].
DiemChiaSe giaiMaToken(String token, {required int bayGio}) {
  if (token.isEmpty ||
      token.length > 4096 ||
      !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(token)) {
    throw const NgoaiLeToken(LoiToken.hong);
  }
  final Uint8List b;
  try {
    b = base64Url.decode(base64Url.normalize(token));
  } on FormatException {
    throw const NgoaiLeToken(LoiToken.hong);
  }
  if (b.length < 19) throw const NgoaiLeToken(LoiToken.hong);
  final than = Uint8List.sublistView(b, 0, b.length - 4);
  final bd = ByteData.sublistView(b);
  if (bd.getUint32(b.length - 4) != crc32(than)) {
    throw const NgoaiLeToken(LoiToken.hong);
  }
  if (b[0] != _phienBan) throw const NgoaiLeToken(LoiToken.phienBanLa);
  final co = b[1];
  if (co & ~3 != 0) throw const NgoaiLeToken(LoiToken.hong);
  final viDo = bd.getInt32(2) / 1e7;
  final kinhDo = bd.getInt32(6) / 1e7;
  final hetHan = bd.getUint32(10);
  var i = 14;
  double? caoDo;
  try {
    if (co & 1 != 0) {
      if (i + 4 > than.length) throw const FormatException('caoDo');
      caoDo = bd.getInt32(i) / 10;
      i += 4;
    }
    final (ten, sauTen) = _docChuoi(than, i);
    i = sauTen;
    var ghi = '';
    if (co & 2 != 0) (ghi, i) = _docChuoi(than, i);
    if (i != than.length) throw const NgoaiLeToken(LoiToken.hong);
    final loi = kiemDiem(ten: ten, viDo: viDo, kinhDo: kinhDo, caoDo: caoDo);
    if (loi.isNotEmpty ||
        ten.runes.length > tenToiDa ||
        ghi.runes.length > ghiChuChiaSeToiDa) {
      throw const NgoaiLeToken(LoiToken.hong);
    }
    if (bayGio > hetHan) throw const NgoaiLeToken(LoiToken.hetHan);
    return (
      ten: ten,
      viDo: viDo,
      kinhDo: kinhDo,
      caoDo: caoDo,
      ghiChu: ghi,
      hetHan: hetHan,
    );
  } on FormatException {
    throw const NgoaiLeToken(LoiToken.hong);
  }
}

/// Lấy token từ link / đường dẫn `/w/<token>` (bỏ query, fragment, `/` cuối).
String? tokenTuLink(String link) {
  final m = RegExp(r'(?:^|/)w/([A-Za-z0-9_-]+)/?(?:[?#].*)?$').firstMatch(link);
  return m?[1];
}

Uint8List _i32(int v) =>
    (ByteData(4)..setUint32(0, v & 0xffffffff)).buffer.asUint8List();

void _chuoi(BytesBuilder b, String s) {
  final u = utf8.encode(s);
  var n = u.length;
  // varint LEB128.
  while (n >= 0x80) {
    b.addByte((n & 0x7f) | 0x80);
    n >>= 7;
  }
  b
    ..addByte(n)
    ..add(u);
}

/// Chuỗi UTF-8 có độ dài varint tại [tu] -> (chuỗi, vị trí sau chuỗi).
/// Thiếu byte / UTF-8 hỏng -> [FormatException].
(String, int) _docChuoi(Uint8List b, int tu) {
  var i = tu;
  var n = 0;
  var dich = 0;
  while (true) {
    if (dich > 14 || i >= b.length) throw const FormatException('varint');
    final x = b[i++];
    n |= (x & 0x7f) << dich;
    if (x < 0x80) break;
    dich += 7;
  }
  if (i + n > b.length) throw const FormatException('chuoi');
  return (utf8.decode(Uint8List.sublistView(b, i, i + n)), i + n);
}

final _bangCrc = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
});

/// CRC-32 (IEEE 802.3, như zlib).
int crc32(List<int> b) {
  var c = 0xffffffff;
  for (final x in b) {
    c = _bangCrc[(c ^ x) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}
