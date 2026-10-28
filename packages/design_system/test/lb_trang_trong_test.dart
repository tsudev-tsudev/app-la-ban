import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LbTrangTrong hiện đủ phần có truyền, cuộn khi màn thấp', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LbTheme.light,
        home: const Scaffold(
          body: LbTrangTrong(
            hinh: LbIcon(LbIcons.diemMoc, size: 120),
            tieuDe: 'Tiêu đề',
            moTa: 'Mô tả dài để màn thấp phải cuộn mà không tràn.',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Tiêu đề'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: LbTheme.dark,
        home: const Scaffold(body: LbTrangTrong(hinh: SizedBox(height: 10))),
      ),
    );
    expect(find.byType(Text), findsNothing);
  });

  test('LbIconData.toString có tên tệp', () {
    expect('${LbIcons.khien}', 'LbIconData(khien)');
  });
}
