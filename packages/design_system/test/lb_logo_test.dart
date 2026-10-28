import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _khung(Widget con, {bool giamChuyenDong = false, Color? nen}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: giamChuyenDong),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: nen ?? LbColors.light.bg,
        child: Center(child: RepaintBoundary(child: con)),
      ),
    ),
  );
}

void main() {
  testWidgets('golden: logo tĩnh nền sáng / tối', (tester) async {
    tester.view
      ..physicalSize = const Size(512, 256)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _khung(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LbLogo(size: 200),
            const SizedBox(width: 24),
            ColoredBox(
              color: LbColors.dark.bg,
              child: const LbLogo(size: 200, gocKim: 0.6),
            ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(Row),
      matchesGoldenFile('goldens/lb_logo.png'),
    );
  });

  testWidgets('nhãn trợ năng chỉ có khi truyền semanticLabel', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(_khung(const LbLogo(semanticLabel: 'La bàn')));
    expect(find.bySemanticsLabel('La bàn'), findsOneWidget);
    await tester.pumpWidget(_khung(const LbLogo()));
    expect(find.bySemanticsLabel('La bàn'), findsNothing);
    h.dispose();
  });

  testWidgets('hoạt ảnh chạy rồi gọi onXong một lần, kim về Bắc', (
    tester,
  ) async {
    var soLan = 0;
    await tester.pumpWidget(_khung(LbLogoDong(onXong: () => soLan++)));
    await tester.pump(const Duration(milliseconds: 100));
    final giua = tester.widget<LbLogo>(find.byType(LbLogo));
    expect(giua.gocKim, isNot(0));
    expect(soLan, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<LbLogo>(find.byType(LbLogo)).gocKim, 0);
    expect(soLan, 1);
  });

  testWidgets('giảm chuyển động: vẽ tĩnh và báo xong ngay', (tester) async {
    var soLan = 0;
    await tester.pumpWidget(
      _khung(LbLogoDong(onXong: () => soLan++), giamChuyenDong: true),
    );
    await tester.pump();
    expect(tester.widget<LbLogo>(find.byType(LbLogo)).gocKim, 0);
    expect(soLan, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('shouldRepaint theo góc kim', () {
    const a = LbLogoPainter();
    expect(a.shouldRepaint(const LbLogoPainter()), isFalse);
    expect(a.shouldRepaint(const LbLogoPainter(gocKim: 1)), isTrue);
  });
}
