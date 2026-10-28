import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('t <= 0 trả biên độ ban đầu', () {
    expect(gocKimTatDan(0), 0.9);
    expect(gocKimTatDan(-1, bienDo: 0.5), 0.5);
  });

  test('biên độ không vượt đường bao tắt dần', () {
    for (var t = 0.01; t < 2; t += 0.01) {
      expect(
        gocKimTatDan(t).abs(),
        lessThanOrEqualTo(0.9 * math.exp(-3.2 * t) + 1e-12),
      );
    }
  });

  test('dao động đổi chiều rồi về gần 0', () {
    expect(gocKimTatDan(1 / 3.2), lessThan(0));
    expect(gocKimTatDan(1.8).abs(), lessThan(0.005));
  });
}
