import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// Đọc chứng chỉ X.509 tối thiểu để tính pin SPKI (SEC-NET): PEM -> DER ->
// SubjectPublicKeyInfo -> SHA-256 base64 (cùng dạng `openssl ... | base64`).

/// Khối `-----BEGIN CERTIFICATE-----` -> DER; sai dạng -> null.
Uint8List? pemSangDer(String pem) {
  final m = RegExp(
    r'-----BEGIN CERTIFICATE-----([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----',
  ).firstMatch(pem);
  if (m == null) return null;
  try {
    return base64.decode(m.group(1)!.replaceAll(RegExp(r'\s'), ''));
  } on FormatException {
    return null;
  }
}

/// Một phần tử DER: thẻ, vị trí bắt đầu nội dung, độ dài nội dung.
typedef _Tlv = ({int the, int dau, int dai});

_Tlv? _doc(Uint8List b, int i) {
  if (i + 2 > b.length) return null;
  final the = b[i];
  var dai = b[i + 1];
  var dau = i + 2;
  if (dai & 0x80 != 0) {
    final soByte = dai & 0x7f;
    if (soByte == 0 || soByte > 3 || dau + soByte > b.length) return null;
    dai = 0;
    for (var k = 0; k < soByte; k++) {
      dai = (dai << 8) | b[dau + k];
    }
    dau += soByte;
  }
  if (dau + dai > b.length) return null;
  return (the: the, dau: dau, dai: dai);
}

/// SubjectPublicKeyInfo (nguyên khối DER) của chứng chỉ; sai cấu trúc -> null.
Uint8List? spkiCuaChungChi(Uint8List der) {
  final cert = _doc(der, 0);
  if (cert == null || cert.the != 0x30) return null;
  final tbs = _doc(der, cert.dau);
  if (tbs == null || tbs.the != 0x30) return null;
  var i = tbs.dau;
  final dauVersion = _doc(der, i);
  if (dauVersion == null) return null;
  // [0] version là tuỳ chọn.
  if (dauVersion.the == 0xa0) i = dauVersion.dau + dauVersion.dai;
  // serialNumber, signature, issuer, validity, subject.
  for (var k = 0; k < 5; k++) {
    final t = _doc(der, i);
    if (t == null) return null;
    i = t.dau + t.dai;
  }
  final spki = _doc(der, i);
  if (spki == null || spki.the != 0x30) return null;
  return Uint8List.sublistView(der, i, spki.dau + spki.dai);
}

/// Pin SPKI SHA-256 base64 của chứng chỉ PEM; sai dạng -> null.
String? pinCuaPem(String pem) {
  final der = pemSangDer(pem);
  final spki = der == null ? null : spkiCuaChungChi(der);
  return spki == null ? null : base64.encode(sha256.convert(spki).bytes);
}
