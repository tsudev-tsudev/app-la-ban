import 'package:flutter_test/flutter_test.dart';
import 'package:test_kit/test_kit.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

void main() {
  setUpAll(napFontThat);

  testWidgets('ma trận 12 kích thước x theme x ngôn ngữ x cỡ chữ: không tràn', (
    tester,
  ) async {
    await kiemMaTran(tester, (o) => khungThu(const ManDiem(), o: o));
  });

  testWidgets('golden', (tester) async {
    await chupGolden(
      tester,
      'man_diem',
      (o) => khungThu(const ManDiem(), o: o),
    );
  });
}
