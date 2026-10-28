import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

void main() {
  test('mã hoá -> giải mã giữ nguyên, w null thành NaN và ngược lại', () {
    const ds = [
      MauCamBien(LoaiMau.tu, 123456789012, x: 1, y: 2, z: 3, doChinhXac: 2),
      MauCamBien(LoaiMau.xoayVector, 5, x: 0.1, y: 0.2, z: 0.3, w: 0.9),
    ];
    final lai = giaiMaLo(maHoaLo(ds));
    expect(lai, hasLength(2));
    expect(lai[0].loai, LoaiMau.tu);
    expect(lai[0].tNs, 123456789012);
    expect(lai[0].w, isNull);
    expect(lai[0].doChinhXac, 2);
    expect(lai[1].w, 0.9);
    expect(lai[1].toString(), contains('xoayVector'));
  });

  test('bỏ qua loại lạ, phần dư cuối lô, kẹp độ chính xác', () {
    final lo = Float64List.fromList([
      99, 0, 0, 0, 0, double.nan, 3, //
      4, 1, 0.1, 0.2, 0.3, double.nan, 7, //
      2, 3,
    ]);
    final ds = giaiMaLo(lo);
    expect(ds, hasLength(1));
    expect(ds.single.loai, LoaiMau.conQuay);
    expect(ds.single.doChinhXac, 3);
  });

  test('khaNangTuMap: thiếu khoá = false', () {
    final k = khaNangTuMap({'tu': true, 'conQuay': true, 'giaToc': 1});
    expect(k.tu, isTrue);
    expect(k.conQuay, isTrue);
    expect(k.giaToc, isFalse);
    expect(k.xoayVector, isFalse);
  });

  test('mã loại là hợp đồng với native - không đổi', () {
    expect(LoaiMau.values.map((l) => l.ma), [0, 1, 2, 3, 4, 5, 6]);
  });
}
