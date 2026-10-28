import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_kit/test_kit.dart';

void main() {
  setUpAll(napFontThat);

  test('ma trận đủ 12 x 2 x 3 x 3 ô, kích thước không trùng', () {
    expect(toHop(), hasLength(12 * 2 * 3 * 3));
    expect(manHinh12.map((m) => m.kichCo).toSet(), hasLength(12));
    expect(manHinh12.map((m) => m.ten).toSet(), hasLength(12));
  });

  test('12 kích thước phủ đủ 3 breakpoint', () {
    final rong = manHinh12.map((m) => m.kichCo.width);
    expect(rong.where((w) => w < 600), isNotEmpty);
    expect(rong.where((w) => w >= 600 && w < 840), isNotEmpty);
    expect(rong.where((w) => w >= 840), isNotEmpty);
  });

  testWidgets('kiemMaTran đỏ khi bố cục tràn', (tester) async {
    Object? loi;
    try {
      await kiemMaTran(
        tester,
        (o) => khungThu(
          const Scaffold(
            body: Row(children: [SizedBox(width: 700, height: 10)]),
          ),
          o: o,
        ),
        dsO: toHop(dsManHinh: [manHinh12.first], dsNgonNgu: [ngonNgu3.first]),
      );
    } on TestFailure catch (e) {
      loi = e;
    }
    expect(loi, isA<TestFailure>());
    expect('$loi', contains('se-320x568'));
  });

  testWidgets('kiemMaTran xanh khi bố cục vừa', (tester) async {
    await kiemMaTran(
      tester,
      (o) => khungThu(const Scaffold(body: Text('ok')), o: o),
      dsO: toHop(dsManHinh: [manHinh12.first]),
    );
  });

  testWidgets('chupGolden so ảnh từng ô (thiếu ảnh -> đỏ)', (tester) async {
    Object? loi;
    try {
      await chupGolden(
        tester,
        'khong-co',
        (o) => khungThu(const Scaffold(body: Text('x')), o: o),
        dsO: [oChup.first],
      );
    } on TestFailure catch (e) {
      loi = e;
    } on Object catch (e) {
      loi = e;
    }
    expect(loi, isNotNull);
  });

  test('nạp font hai lần không lỗi', () async {
    await napFontThat();
    await napFontThat();
  });

  test('tên golden theo ô', () {
    expect(
      tenGolden('x', oChup.last),
      'goldens/x/se-320x568-dark-en-XA-x2.0.png',
    );
  });
}
