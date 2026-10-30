import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

void main() {
  test('kiemDiem', () {
    expect(kiemDiem(ten: 'A', viDo: 1, kinhDo: 2), isEmpty);
    expect(kiemDiem(ten: '  ', viDo: 1, kinhDo: 2), {LoiDiem.tenTrong});
    expect(kiemDiem(ten: 'a' * 121, viDo: 1, kinhDo: 2), {LoiDiem.tenDai});
    expect(kiemDiem(ten: 'A', viDo: 90.1, kinhDo: 181), {
      LoiDiem.viDo,
      LoiDiem.kinhDo,
    });
    expect(kiemDiem(ten: 'A', viDo: null, kinhDo: double.nan), {
      LoiDiem.viDo,
      LoiDiem.kinhDo,
    });
    expect(kiemDiem(ten: 'A', viDo: 0, kinhDo: 0, caoDo: 1000000), {
      LoiDiem.caoDo,
    });
    expect(kiemDiem(ten: 'A', viDo: 0, kinhDo: 0, ghiChu: 'x' * 2001), {
      LoiDiem.ghiChuDai,
    });
  });

  test('taoIdDiem: UUID v4, khác nhau', () {
    final a = taoIdDiem(Random(1));
    expect(
      a,
      matches(
        RegExp(
          '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
    expect(taoIdDiem(), isNot(taoIdDiem()));
  });

  test('catChuoi không cắt đôi ký tự ngoài BMP', () {
    expect(catChuoi('a😀b', 2), 'a😀');
    expect(catChuoi('abc', 5), 'abc');
  });

  test('copyWith giữ id / taoLuc, đặt caoDo null được', () {
    const d = DiemMoc(
      id: 'i',
      ten: 'A',
      viDo: 1,
      kinhDo: 2,
      caoDo: 3,
      taoLuc: 1,
      suaLuc: 1,
    );
    final e = d.copyWith(ten: 'B', caoDo: () => null, suaLuc: 5);
    expect((e.id, e.ten, e.caoDo, e.taoLuc, e.suaLuc), ('i', 'B', null, 1, 5));
    expect(d.copyWith(), d);
    expect(d.hashCode, d.copyWith().hashCode);
  });
}
