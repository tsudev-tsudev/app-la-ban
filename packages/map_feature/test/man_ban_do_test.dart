import 'package:flutter_test/flutter_test.dart';
import 'package:map_feature/map_feature.dart';
import 'package:test_kit/test_kit.dart';

void main() {
  setUpAll(napFontThat);

  testWidgets('ma trận 12 kích thước x theme x ngôn ngữ x cỡ chữ: không tràn', (
    tester,
  ) async {
    await kiemMaTran(tester, (o) => khungThu(const ManBanDo(), o: o));
  });

  testWidgets('golden', (tester) async {
    await chupGolden(
      tester,
      'man_ban_do',
      (o) => khungThu(const ManBanDo(), o: o),
    );
  });
}
