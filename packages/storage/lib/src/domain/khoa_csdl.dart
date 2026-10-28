import 'dart:typed_data';

/// Độ dài khoá SQLCipher thô (AES-256).
const doDaiKhoa = 32;

/// Câu `PRAGMA key` dạng khoá thô `x'..'` - bỏ qua PBKDF2 (khoá đã ngẫu nhiên
/// 256 bit) nên mở CSDL nhanh. Ném [ArgumentError] nếu sai độ dài.
String pragmaKhoa(Uint8List khoa) {
  if (khoa.length != doDaiKhoa) {
    throw ArgumentError.value(khoa.length, 'khoa', 'cần $doDaiKhoa byte');
  }
  final hex = StringBuffer();
  for (final b in khoa) {
    hex.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return "PRAGMA key = \"x'$hex'\"";
}
