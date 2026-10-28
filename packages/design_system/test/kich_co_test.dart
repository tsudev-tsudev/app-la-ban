import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LbKichCo.tuRong theo ranh giới 600 / 840', () {
    expect(LbKichCo.tuRong(320), LbKichCo.compact);
    expect(LbKichCo.tuRong(599.9), LbKichCo.compact);
    expect(LbKichCo.tuRong(600), LbKichCo.medium);
    expect(LbKichCo.tuRong(839.9), LbKichCo.medium);
    expect(LbKichCo.tuRong(840), LbKichCo.expanded);
    expect(LbKichCo.tuRong(2560), LbKichCo.expanded);
  });

  test('giá trị bất thường coi như compact', () {
    expect(LbKichCo.tuRong(-1), LbKichCo.compact);
    expect(LbKichCo.tuRong(double.nan), LbKichCo.compact);
    expect(LbKichCo.tuRong(double.infinity), LbKichCo.expanded);
  });
}
