import 'package:flutter_test/flutter_test.dart';
import 'package:map_feature/map_feature.dart';
import 'package:test_kit/test_kit.dart';

import 'thu_chung.dart';

void main() {
  setUpAll(napFontThat);

  testWidgets('ma trận 12 kích thước x theme x ngôn ngữ x cỡ chữ: không tràn', (
    tester,
  ) async {
    await kiemMaTran(tester, (o) => banDoThu(const ManBanDo(), o: o));
  });

  testWidgets('golden', (tester) async {
    await chupGolden(
      tester,
      'man_ban_do',
      (o) => banDoThu(const ManBanDo(), o: o),
    );
  });

  testWidgets('chưa có quyền: nút vị trí xin quyền', (tester) async {
    var xin = 0;
    await tester.pumpWidget(
      banDoThu(
        const ManBanDo(),
        o: oChup.first,
        them: [xinQuyenViTriBanDoProvider.overrideWithValue(() async => xin++)],
      ),
    );
    await tester.tap(find.byTooltip('Vị trí của tôi'));
    await tester.pump();
    expect(xin, 1);
  });

  testWidgets('có quyền, chưa có vị trí: báo đang chờ GPS', (tester) async {
    await tester.pumpWidget(
      banDoThu(
        const ManBanDo(),
        o: oChup.first,
        them: [coQuyenViTriBanDoProvider.overrideWithValue(true)],
      ),
    );
    await tester.tap(find.byTooltip('Vị trí của tôi'));
    await tester.pump();
    expect(find.text('Chưa có vị trí - đang chờ GPS.'), findsOneWidget);
  });

  testWidgets('nút hướng đổi chế độ, nút tải mở màn vùng offline', (
    tester,
  ) async {
    await tester.pumpWidget(banDoThu(const ManBanDo(), o: oChup.first));
    await tester.tap(find.byTooltip('Xoay bản đồ theo hướng'));
    await tester.pump();
    expect(find.byTooltip('Đưa hướng bắc lên trên'), findsOneWidget);
    await tester.tap(find.byTooltip('Bản đồ ngoại tuyến'));
    await tester.pumpAndSettle();
    expect(find.byType(ManVungOffline), findsOneWidget);
  });
}
