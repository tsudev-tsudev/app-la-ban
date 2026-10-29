import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// Chuỗi thiết bị ký - PHẢI khớp từng byte với workers/api/src/thuan/ma-hoa.ts
// (test chéo bằng cùng vector ở cả hai phía).

/// base64url không đệm.
String b64url(List<int> byte) => base64Url.encode(byte).replaceAll('=', '');

String chuoiDangKy(
  String thachThuc,
  String installationId,
  String khoaCongKhai,
) => 'la-ban/v1/dang-ky\n$thachThuc\n$installationId\n$khoaCongKhai';

String chuoiXacThuc(String thachThuc, String thietBiId) =>
    'la-ban/v1/xac-thuc\n$thachThuc\n$thietBiId';

String chuoiLamMoi(String refreshToken, int ts, String nonce) =>
    'la-ban/v1/lam-moi\n$refreshToken\n$ts\n$nonce';

/// Mã hoá phần trăm RFC 3986: chỉ giữ `A-Z a-z 0-9 - . _ ~` (byte UTF-8,
/// hex HOA) - khớp `maHoaRfc3986` của Worker.
String maHoaRfc3986(String s) {
  final b = StringBuffer();
  for (final x in utf8.encode(s)) {
    final giu =
        (x >= 0x30 && x <= 0x39) ||
        (x >= 0x41 && x <= 0x5a) ||
        (x >= 0x61 && x <= 0x7a) ||
        x == 0x2d ||
        x == 0x2e ||
        x == 0x5f ||
        x == 0x7e;
    b.write(
      giu
          ? String.fromCharCode(x)
          : '%${x.toRadixString(16).toUpperCase().padLeft(2, '0')}',
    );
  }
  return b.toString();
}

/// Query (không `?`) -> dạng chuẩn: giải mã từng cặp (`+` = khoảng trắng),
/// sắp theo khoá rồi giá trị (đơn vị mã UTF-16, như `<` của JS), mã hoá lại
/// RFC 3986, nối `&`. Khớp `querySapXep` (URLSearchParams) của Worker.
String querySapXep(String query) {
  final cap = <(String, String)>[];
  for (final phan in query.split('&')) {
    if (phan.isEmpty) continue;
    final i = phan.indexOf('=');
    final k = i < 0 ? phan : phan.substring(0, i);
    final v = i < 0 ? '' : phan.substring(i + 1);
    cap.add((Uri.decodeQueryComponent(k), Uri.decodeQueryComponent(v)));
  }
  cap.sort((a, b) {
    final c = a.$1.compareTo(b.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  return cap
      .map((p) => '${maHoaRfc3986(p.$1)}=${maHoaRfc3986(p.$2)}')
      .join('&');
}

/// SHA-256 hex thường của thân request (rỗng khi GET).
String bamThan(List<int> than) => sha256.convert(than).toString();

/// Chuỗi chuẩn ký request (Spec §7.5, SEC-NET):
/// `METHOD\nPATH\nSORTED_QUERY\nSHA256_HEX(BODY)\nTIMESTAMP\nNONCE`.
String chuoiYeuCau({
  required String phuongThuc,
  required String duongDan,
  required String query,
  required String bamThan,
  required int ts,
  required String nonce,
}) =>
    '${phuongThuc.toUpperCase()}\n$duongDan\n${querySapXep(query)}\n'
    '$bamThan\n$ts\n$nonce';

/// requestHash gửi Play Integrity: base64url(SHA-256(chuỗi)) - gắn token với
/// thách thức + khoá của đúng yêu cầu này (server tính lại để so).
String requestHash(String chuoi) =>
    b64url(sha256.convert(utf8.encode(chuoi)).bytes);

/// UUID v4 ngẫu nhiên (Installation ID - ID-01: đổi khi cài lại, không gắn
/// phần cứng).
String uuidV4([Random? r]) {
  final ng = r ?? Random.secure();
  final b = Uint8List.fromList(List.generate(16, (_) => ng.nextInt(256)));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Nonce ngẫu nhiên base64url (khớp mẫu `[A-Za-z0-9_-]{16,128}` của server).
String nonceNgauNhien([Random? r]) {
  final ng = r ?? Random.secure();
  return b64url(List.generate(24, (_) => ng.nextInt(256)));
}
