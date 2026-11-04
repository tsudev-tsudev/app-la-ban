import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget w, {bool giam = false}) => MaterialApp(
  theme: LbTheme.light,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: giam),
    child: w,
  ),
);

void main() {
  group('LbNutNoi', () {
    testWidgets('không nền, vùng chạm >= 48 dp, nhãn trợ năng, bấm được', (
      tester,
    ) async {
      var bam = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: LbNutNoi(
                icon: LbIcons.ghimGps,
                nhan: 'Vị trí của tôi',
                hienNhan: false,
                onPressed: () => bam++,
              ),
            ),
          ),
        ),
      );
      final co = tester.getSize(find.byType(LbNutNoi));
      expect(co.width, greaterThanOrEqualTo(48));
      expect(co.height, greaterThanOrEqualTo(48));
      expect(
        find.descendant(
          of: find.byType(LbNutNoi),
          matching: find.byType(Material),
        ),
        findsNothing,
        reason: 'không có nền khối (FAB / Material)',
      );
      expect(find.bySemanticsLabel('Vị trí của tôi'), findsOneWidget);
      await tester.tap(find.byType(LbNutNoi));
      expect(bam, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('có nhãn hiện chữ; null onPressed -> tắt', (tester) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Center(
              child: LbNutNoi(
                icon: LbIcons.bacThuc,
                nhan: 'Bắc lên trên',
                onPressed: null,
              ),
            ),
          ),
        ),
      );
      // Hai lớp: viền màu nền + chữ.
      expect(find.text('Bắc lên trên'), findsNWidgets(2));
      expect(
        tester.getSemantics(find.byType(LbNutNoi)),
        matchesSemantics(
          label: 'Bắc lên trên',
          isButton: true,
          hasEnabledState: true,
        ),
      );
    });
  });

  group('LbHeaderMo', () {
    Widget man({bool tatMo = false, bool giam = false}) => _app(
      Scaffold(
        extendBodyBehindAppBar: true,
        appBar: LbHeaderMo(title: const Text('Điểm'), tatMo: tatMo),
        body: ListView(children: [for (var i = 0; i < 30; i++) Text('$i')]),
      ),
      giam: giam,
    );

    testWidgets('mặc định: kính mờ (BackdropFilter)', (tester) async {
      await tester.pumpWidget(man());
      expect(find.byType(BackdropFilter), findsOneWidget);
      // Lớp kính phủ kín cả header (lỗi M32: DecoratedBox không con co 0x0).
      final kinh = find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(DecoratedBox),
      );
      expect(
        tester.getSize(kinh).height,
        greaterThanOrEqualTo(kToolbarHeight),
      );
      // Chủ đề sáng: icon thanh trạng thái TỐI (lỗi thấy trên M32).
      expect(
        tester
            .widget<AppBar>(find.byType(AppBar))
            .systemOverlayStyle
            ?.statusBarIconBrightness,
        Brightness.dark,
      );
      expect(find.text('Điểm'), findsOneWidget);
    });

    testWidgets('máy yếu hoặc Reduce motion: nền đặc, không blur', (
      tester,
    ) async {
      await tester.pumpWidget(man(tatMo: true));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.byType(AppBar),
                matching: find.byType(ColoredBox),
              ).first,
            )
            .height,
        greaterThanOrEqualTo(kToolbarHeight),
      );
      await tester.pumpWidget(man(giam: true));
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
