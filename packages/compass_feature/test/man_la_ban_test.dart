import 'package:compass_feature/compass_feature.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_kit/test_kit.dart';

void main() {
  setUpAll(napFontThat);

  testWidgets('ma trận 12 kích thước x theme x ngôn ngữ x cỡ chữ: không tràn', (
    tester,
  ) async {
    await kiemMaTran(tester, (o) => khungThu(const ManLaBan(), o: o));
  });

  testWidgets('golden', (tester) async {
    await chupGolden(
      tester,
      'man_la_ban',
      (o) => khungThu(const ManLaBan(), o: o),
    );
  });
}
