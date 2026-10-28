import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_kit/test_kit.dart';

Widget _hang(Color nen, Color net) => ColoredBox(
  color: nen,
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final i in LbIcons.all)
          Padding(
            padding: const EdgeInsets.all(12),
            child: LbIcon(i, size: 48, color: net),
          ),
      ],
    ),
  ),
);

void main() {
  setUpAll(napFontThat);

  test('bộ icon đủ 12 tệp design/icons, mỗi icon có nét', () {
    expect(LbIcons.all, hasLength(12));
    expect(LbIcons.all.map((i) => i.ten).toSet(), hasLength(12));
    for (final i in LbIcons.all) {
      final b = i.taoPath().getBounds();
      expect(b.isEmpty, isFalse, reason: i.ten);
      // Quy ước lề 2 của khung 24 (Spec §2.3).
      expect(b.left >= 1.99 && b.top >= 1.99, isTrue, reason: i.ten);
      expect(b.right <= 22.01 && b.bottom <= 22.01, isTrue, reason: i.ten);
    }
  });

  testWidgets('golden: 12 icon nền sáng / tối (đối chiếu xem-truoc.png)', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(912, 192)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hang(LbColors.light.bg, LbColors.light.text),
            _hang(LbColors.dark.bg, LbColors.dark.text),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/lb_icons.png'),
    );
  });

  testWidgets('cỡ / màu lấy từ IconTheme khi không truyền', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: IconTheme(
          data: IconThemeData(size: 40, color: Color(0xFF123456)),
          child: Center(child: LbIcon(LbIcons.khien)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(LbIcon)), const Size.square(40));
    final p = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(LbIcon),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((p.painter! as LbIconPainter).color, const Color(0xFF123456));
  });

  testWidgets('nhãn trợ năng chỉ có khi truyền semanticLabel', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LbIcon(LbIcons.banDo, semanticLabel: 'Bản đồ'),
      ),
    );
    expect(find.bySemanticsLabel('Bản đồ'), findsOneWidget);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LbIcon(LbIcons.banDo),
      ),
    );
    expect(find.bySemanticsLabel('Bản đồ'), findsNothing);
    h.dispose();
  });
}
