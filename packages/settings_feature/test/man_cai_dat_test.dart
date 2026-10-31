import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:test_kit/test_kit.dart';

void main() {
  setUpAll(napFontThat);

  Widget dung(OMaTran o) => ProviderScope(
    child: khungThu(const ManCaiDat(phienBan: '0.1.0+1'), o: o),
  );

  testWidgets('trợ năng: vùng chạm, nhãn, tương phản', (tester) async {
    await kiemTroNang(tester, dung);
  });

  testWidgets('ma trận 12 kích thước x theme x ngôn ngữ x cỡ chữ: không tràn', (
    tester,
  ) async {
    await kiemMaTran(tester, dung);
  });

  testWidgets('golden', (tester) async {
    await chupGolden(tester, 'man_cai_dat', dung);
  });

  testWidgets('chọn ngôn ngữ / giao diện cập nhật provider', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: khungThu(const ManCaiDat(phienBan: '1.0.0'), o: oChup.first),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ngon-ngu-en')));
    await tester.pump();
    expect(c.read(caiDatProvider).ngonNgu, LuaChonNgonNgu.en);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('che-do-toi')),
      100,
    );
    await tester.tap(find.byKey(const ValueKey('che-do-toi')));
    await tester.pump();
    expect(c.read(caiDatProvider).cheDo, CheDoGiaoDien.toi);
    expect(find.text('Phiên bản 1.0.0'), findsOneWidget);
  });

  testWidgets('mở trang giấy phép', (tester) async {
    await tester.pumpWidget(dung(oChup.first));
    await tester.scrollUntilVisible(find.text('Giấy phép mã nguồn mở'), 100);
    await tester.tap(find.text('Giấy phép mã nguồn mở'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
