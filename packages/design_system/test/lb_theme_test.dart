import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ThemeData sáng / tối lấy màu từ token, chữ trên nền đạt AA', () {
    for (final (t, c) in [
      (LbTheme.light, LbColors.light),
      (LbTheme.dark, LbColors.dark),
    ]) {
      expect(t.colorScheme.primary, c.primaryDeep);
      expect(t.colorScheme.onSurface, c.text);
      expect(t.scaffoldBackgroundColor, c.bg);
      expect(t.extension<LbThemeExt>()!.colors, c);
    }
    expect(LbTheme.light.brightness, Brightness.light);
    // Icon tab đang chọn dùng màu chữ chính (không trắng trên cyan nhạt).
    final nav = LbTheme.light.navigationBarTheme.iconTheme!;
    expect(nav.resolve({WidgetState.selected})!.color, LbColors.light.text);
    expect(nav.resolve({})!.color, LbColors.light.textMuted);
    expect(LbTheme.dark.colorScheme.onSecondaryContainer, LbColors.dark.text);
    expect(LbTheme.dark.brightness, Brightness.dark);
  });

  test('chữ dùng Be Vietnam Pro của package design_system', () {
    final f = LbTheme.light.textTheme.bodyLarge!.fontFamily;
    expect(f, 'packages/design_system/BeVietnamPro');
    expect(LbTheme.dark.textTheme.titleLarge!.color, LbColors.dark.text);
  });

  testWidgets('LbThemeExt.of: lấy theo theme, thiếu thì mặc định sáng', (
    tester,
  ) async {
    late LbThemeExt a;
    late LbThemeExt b;
    await tester.pumpWidget(
      Theme(
        data: LbTheme.dark,
        child: Builder(
          builder: (c) {
            a = LbThemeExt.of(c);
            return Theme(
              data: ThemeData(),
              child: Builder(
                builder: (c) {
                  b = LbThemeExt.of(c);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(a, LbThemeExt.dark);
    expect(b, LbThemeExt.light);
  });

  test('LbThemeExt lerp / copyWith', () {
    const s = LbThemeExt.light;
    expect(s.lerp(LbThemeExt.dark, 0.4), s);
    expect(s.lerp(LbThemeExt.dark, 0.6), LbThemeExt.dark);
    expect(s.lerp(null, 0.9), s);
    expect(s.copyWith(colors: LbColors.dark).colors, LbColors.dark);
    expect(s.copyWith().glass, s.glass);
  });

  testWidgets('đăng ký giấy phép OFL của font', (tester) async {
    LicenseRegistry.reset();
    dangKyGiayPhepFont();
    final ds = await tester.runAsync(() => LicenseRegistry.licenses.toList());
    final font = ds!.where((e) => e.packages.contains('Be Vietnam Pro'));
    expect(font, hasLength(1));
    final doan = font.single.paragraphs.map((p) => p.text).join('\n');
    expect(doan, contains('SIL OPEN FONT LICENSE'));
  });

  testWidgets('chuyển trang: có hoạt ảnh, Reduce motion thì hiện ngay', (
    tester,
  ) async {
    for (final giam in [false, true]) {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: LbTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: giam),
            child: child!,
          ),
          home: const Text('1'),
        ),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('2')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final giua = tester.getRect(find.text('2'));
      await tester.pumpAndSettle();
      final cuoi = tester.getRect(find.text('2'));
      expect(giua == cuoi, giam, reason: 'giam=$giam');
    }
  });
}
