import 'dart:async';

import 'package:compass_feature/compass_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:test_kit/test_kit.dart';

HuongDoc doc({
  double phuongVi = 0,
  double docGoc = 0,
  double lan = 0,
  MucTinCay muc = MucTinCay.thap,
  int tNs = 0,
}) => HuongDoc(
  phuongVi: phuongVi,
  phuongViTho: phuongVi,
  doc: docGoc,
  lan: lan,
  theoCamera: false,
  muc: muc,
  nhieuTu: false,
  canHieuChuan: muc == MucTinCay.thap,
  cuongDoTu: 45,
  nguon: NguonHuong.madgwick,
  dungYen: false,
  tNs: tNs,
);

Widget dung(OMaTran o, List<Override> ghiDe) => ProviderScope(
  overrides: ghiDe,
  child: khungThu(const ManHieuChuan(), o: o),
);

void main() {
  setUpAll(napFontThat);

  testWidgets('trợ năng: vùng chạm, nhãn, tương phản', (tester) async {
    await kiemTroNang(
      tester,
      (o) =>
          dung(o, [huongProvider.overrideWith((ref) => Stream.value(doc()))]),
    );
  });

  testWidgets('ma trận: không tràn', (tester) async {
    await kiemMaTran(
      tester,
      (o) =>
          dung(o, [huongProvider.overrideWith((ref) => Stream.value(doc()))]),
    );
  });

  testWidgets('golden', (tester) async {
    await chupGolden(
      tester,
      'man_hieu_chuan',
      (o) =>
          dung(o, [huongProvider.overrideWith((ref) => Stream.value(doc()))]),
      dsO: [oChup.first, oChup[3]],
    );
  });

  testWidgets('quét đủ hướng + tư thế -> xong, rung một lần', (tester) async {
    var soLan = 0;
    final cho = StreamController<HuongDoc>();
    addTearDown(cho.close);
    await tester.pumpWidget(
      dung(oChup.first, [
        huongProvider.overrideWith((ref) => cho.stream),
        rungProvider.overrideWithValue(() => soLan++),
      ]),
    );
    await tester.pump();
    expect(find.text('Đã quét 0%'), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      cho.add(doc(phuongVi: i * 45.0));
      await tester.pump();
    }
    expect(find.text('Đã quét 67%'), findsOneWidget);
    for (final (d, l) in [
      (30.0, 0.0),
      (-30.0, 0.0),
      (0.0, 30.0),
      (0.0, -30.0),
    ]) {
      cho.add(doc(docGoc: d, lan: l, muc: MucTinCay.cao));
      await tester.pump();
    }
    expect(find.text('Đã quét 100%'), findsOneWidget);
    expect(find.text('Hiệu chuẩn xong. Độ tin cậy: Cao.'), findsOneWidget);
    expect(soLan, 1);
    cho.add(doc());
    await tester.pump();
    expect(soLan, 1);
  });

  testWidgets('giảm chuyển động: không chạy hoạt ảnh', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [huongProvider.overrideWith((ref) => Stream.value(doc()))],
        child: khungThu(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: ManHieuChuan(),
          ),
          o: oChup.first,
        ),
      ),
    );
    await tester.pump();
    // Không còn khung hình nào được lên lịch -> pumpAndSettle dừng ngay.
    await tester.pumpAndSettle();
    expect(find.byType(ManHieuChuan), findsOneWidget);
  });

  testWidgets('nút Xong đóng màn', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [huongProvider.overrideWith((ref) => Stream.value(doc()))],
        child: khungThu(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => moHieuChuan(context),
              child: const Text('mo'),
            ),
          ),
          o: oChup.first,
        ),
      ),
    );
    await tester.tap(find.text('mo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ManHieuChuan), findsOneWidget);
    await tester.tap(find.text('Xong'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ManHieuChuan), findsNothing);
  });
}
