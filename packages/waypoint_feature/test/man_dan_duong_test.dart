import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:sensors/sensors.dart';
import 'package:test_kit/test_kit.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

import 'thu_chung.dart';

final OMaTran o = (
  manHinh: manHinh12[3],
  sang: Brightness.light,
  ngonNgu: LbNgonNgu.vi,
  coChu: 1.0,
);

/// Đứng ở Nhà hát Lớn, dẫn tới Hồ Gươm (~1 km về phía tây bắc).
const ViTriCo nhaHat = ViTriCo((
  viDo: 21.024304,
  kinhDo: 105.857629,
  caoDo: 10,
  saiSoM: 5,
));

const dich = ManDanDuong(ten: 'Hồ Gươm', viDo: 21.0285111, kinhDo: 105.8521822);

void main() {
  setUpAll(napFontThat);

  test(
    'tinhDanDuong: góc quay theo bắc thực, đã tới trong bán kính sai số',
    () {
      final d = tinhDanDuong(
        viDo: 0,
        kinhDo: 0,
        dichViDo: 0,
        dichKinhDo: 0.01,
        huongTu: 80,
        doLech: -2,
      );
      expect(d.phuongVi, closeTo(90, 1e-6));
      expect(d.gocQuay, closeTo(12, 1e-6));
      expect(d.daToi, isFalse);
      expect(
        tinhDanDuong(
          viDo: 0,
          kinhDo: 0,
          dichViDo: 0.0002,
          dichKinhDo: 0,
          saiSoM: 30,
        ).daToi,
        isTrue,
      );
      expect(
        tinhDanDuong(viDo: 0, kinhDo: 0, dichViDo: 1, dichKinhDo: 0).gocQuay,
        isNull,
      );
    },
  );

  testWidgets('dẫn đường: ma trận không tràn + golden', (tester) async {
    await kiemMaTran(tester, (o) => dung(dich, o, ghiDe(viTri: nhaHat)));
    await chupGolden(
      tester,
      'man_dan_duong',
      (o) => dung(dich, o, ghiDe(viTri: nhaHat)),
    );
  });

  testWidgets('khoảng cách + chỉ dẫn quay; không la bàn; chờ GPS', (
    tester,
  ) async {
    datManHinh(tester, o.manHinh);
    await tester.pumpWidget(dung(dich, o, ghiDe(viTri: nhaHat)));
    await tester.pumpAndSettle();
    expect(find.text('730 m'), findsOneWidget);
    expect(find.textContaining('sang trái'), findsOneWidget);
    expect(find.text('Hướng 309° (bắc thực)'), findsOneWidget);
    expect(find.text('Quay 49° sang trái'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      dung(
        dich,
        o,
        ghiDe(
          viTri: nhaHat,
          luongHuong: Stream<HuongDoc>.error(StateError('khong-co')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Máy không có cảm biến la bàn'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(dung(dich, o, ghiDe(viTri: const ViTriDangCho())));
    await tester.pump();
    expect(find.text('Đang chờ vị trí GPS...'), findsOneWidget);
  });

  testWidgets('đã tới nơi', (tester) async {
    datManHinh(tester, o.manHinh);
    await tester.pumpWidget(
      ProviderScope(
        overrides: ghiDe(
          viTri: const ViTriCo((
            viDo: 21.0285,
            kinhDo: 105.85218,
            caoDo: null,
            saiSoM: 8,
          )),
        ),
        child: khungThu(dich, o: o),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã tới nơi'), findsOneWidget);
  });
}
