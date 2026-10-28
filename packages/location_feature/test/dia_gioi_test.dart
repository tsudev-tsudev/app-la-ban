import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_feature/location_feature.dart';

void main() {
  final bd = BanDoDiaGioi.tuBytes(
    File('assets/dia_gioi_vn.bin').readAsBytesSync(),
  );

  test('đủ 34 tỉnh, ~3321 xã, ghi nguồn OSM', () {
    expect(bd.soTinh, 34);
    expect(bd.soXa, inInclusiveRange(3300, 3330));
    expect(bd.nguon, startsWith('OpenStreetMap '));
  });

  test('tra điểm mẫu', () {
    final hn = bd.tra(21.0285, 105.8542)!; // Hồ Gươm
    expect(hn.maTinh, 'VN-HN');
    expect(hn.xa, 'Phường Hoàn Kiếm');
    expect(hn.tenTinh(tiengViet: true), 'Thành phố Hà Nội');
    final sg = bd.tra(10.7769, 106.7009)!; // Nhà hát TP
    expect(sg.maTinh, 'VN-SG');
    expect(sg.xa, isNotNull);
    expect(bd.tra(12.2388, 109.1967)!.maTinh, 'VN-34'); // Nha Trang
    expect(bd.tra(16.4637, 107.5909)!.maTinh, 'VN-26'); // Huế
  });

  test('Hoàng Sa, Trường Sa là đặc khu của Đà Nẵng, Khánh Hòa', () {
    final hs = bd.tra(16.5, 111.6)!;
    expect(hs.maTinh, 'VN-DN');
    expect(hs.xa, 'Đặc khu Hoàng Sa');
    expect(hs.tenXa(tiengViet: false), 'Hoang Sa Special Zone');
    final ts = bd.tra(8.64, 111.92)!;
    expect(ts.maTinh, 'VN-34');
    expect(ts.xa, 'Đặc khu Trường Sa');
  });

  test('ngoài Việt Nam trả null', () {
    expect(bd.tra(13.7563, 100.5018), isNull); // Bangkok
    expect(bd.tra(22.8170, 108.3665), isNull); // Nam Ninh
    expect(bd.tra(0, 0), isNull);
  });

  test('sai định dạng', () {
    expect(
      () => BanDoDiaGioi.tuBytes(Uint8List.fromList('XXXX0000'.codeUnits)),
      throwsFormatException,
    );
  });
}
