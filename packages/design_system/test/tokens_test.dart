import 'dart:ui';

import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

double _tuongPhan(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final sang = l1 > l2 ? l1 : l2;
  final toi = l1 > l2 ? l2 : l1;
  return (sang + 0.05) / (toi + 0.05);
}

void main() {
  for (final (ten, c) in [('light', LbColors.light), ('dark', LbColors.dark)]) {
    group('LbColors.$ten', () {
      test('chữ chính và phụ đạt AA trên mọi nền', () {
        for (final nen in [c.bg, c.surface, c.surfaceRaised]) {
          expect(_tuongPhan(c.text, nen), greaterThanOrEqualTo(4.5));
          expect(_tuongPhan(c.textMuted, nen), greaterThanOrEqualTo(4.5));
          expect(_tuongPhan(c.primaryDeep, nen), greaterThanOrEqualTo(4.5));
        }
      });

      test('chữ trên nút màu đạt AA', () {
        expect(_tuongPhan(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
        expect(
          _tuongPhan(c.onPrimaryDeep, c.primaryDeep),
          greaterThanOrEqualTo(4.5),
        );
        expect(_tuongPhan(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
        expect(
          _tuongPhan(c.onDanger, c.dangerStrong),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }

  test('cyan thương hiệu giữ nguyên ở cả hai theme', () {
    expect(LbColors.light.primary, const Color(0xFF00E5FF));
    expect(LbColors.dark.primary, LbColors.light.primary);
  });

  test('thang khoảng cách theo lưới 4/8pt', () {
    const ds = [
      LbSpacing.xxs,
      LbSpacing.xs,
      LbSpacing.sm,
      LbSpacing.md,
      LbSpacing.lg,
      LbSpacing.xl,
      LbSpacing.xxl,
    ];
    expect(ds, [4, 8, 12, 16, 24, 32, 48]);
  });

  test('telemetry dùng tabular figures', () {
    expect(
      LbType.telemetry.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(LbType.body.fontFamily, 'packages/design_system/BeVietnamPro');
  });

  test('breakpoint và bóng đổ', () {
    expect(LbBreakpoint.medium, lessThan(LbBreakpoint.expanded));
    expect(LbShadows.light.md, hasLength(2));
    expect(LbMotion.fast, lessThan(LbMotion.slow));
    expect(LbGlass.blur, greaterThan(0));
  });
}
