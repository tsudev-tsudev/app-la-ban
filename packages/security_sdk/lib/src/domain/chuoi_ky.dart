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
