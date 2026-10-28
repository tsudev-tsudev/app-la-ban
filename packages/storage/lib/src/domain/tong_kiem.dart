// FNV-1a 64 bit dùng hằng 64 bit - app chỉ chạy native (không biên dịch JS).
// ignore_for_file: avoid_js_rounded_ints

import 'dart:convert';

const _fnvGoc = 0xcbf29ce484222325;
const _fnvNhan = 0x100000001b3;

/// Tổng kiểm FNV-1a 64 bit của dãy dòng (mỗi dòng là danh sách giá trị cột,
/// đã sắp xếp ổn định). Dùng so dữ liệu trước / sau migration - không phải
/// băm mật mã. Giá trị: null / int / double / String / `List<int>` (blob).
String tongKiem(Iterable<List<Object?>> dong) {
  var h = _fnvGoc;
  void them(int b) => h = (h ^ (b & 0xff)) * _fnvNhan;
  void themChuoi(String s) => utf8.encode(s).forEach(them);

  for (final d in dong) {
    for (final v in d) {
      // Tiền tố kiểu để 1 (int) khác 1.0 (double) khác '1' khác null.
      switch (v) {
        case null:
          them(0x00);
        case int():
          them(0x01);
          themChuoi('$v');
        case double():
          them(0x02);
          themChuoi(v.toString());
        case String():
          them(0x03);
          themChuoi(v);
        case List<int>():
          them(0x04);
          v.forEach(them);
        default:
          throw ArgumentError.value(v, 'dong', 'kiểu không hỗ trợ');
      }
      them(0x1f);
    }
    them(0x1e);
  }
  // int Dart 64 bit có dấu: in hai nửa 32 bit để ra hex không dấu.
  String nua(int x) => x.toRadixString(16).padLeft(8, '0');
  return nua(h >>> 32) + nua(h & 0xffffffff);
}
