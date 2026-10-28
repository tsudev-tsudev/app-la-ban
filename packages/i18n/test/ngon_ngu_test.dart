import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

void main() {
  group('LbNgonNgu.chon', () {
    test('lấy ngôn ngữ hỗ trợ đầu tiên theo thứ tự ưu tiên của thiết bị', () {
      expect(LbNgonNgu.chon(const [Locale('vi', 'VN')]), LbNgonNgu.vi);
      expect(LbNgonNgu.chon(const [Locale('en', 'GB')]), LbNgonNgu.en);
      expect(
        LbNgonNgu.chon(const [Locale('fr'), Locale('vi'), Locale('en')]),
        LbNgonNgu.vi,
      );
    });

    test('không khớp / rỗng / null -> en', () {
      expect(LbNgonNgu.chon(const [Locale('ja'), Locale('fr')]), LbNgonNgu.en);
      expect(LbNgonNgu.chon(const []), LbNgonNgu.en);
      expect(LbNgonNgu.chon(null), LbNgonNgu.en);
    });

    test('pseudo-locale chỉ khi khớp đủ en-XA', () {
      expect(LbNgonNgu.chon(const [LbNgonNgu.gia]), LbNgonNgu.gia);
      expect(LbNgonNgu.chon(const [Locale('en', 'US')]), LbNgonNgu.en);
    });
  });

  test('gen-l10n có đủ vi, en và en-XA; hoTro không lộ pseudo-locale', () {
    expect(
      LbL10n.supportedLocales,
      containsAll(<Locale>[LbNgonNgu.vi, LbNgonNgu.en, LbNgonNgu.gia]),
    );
    expect(LbNgonNgu.hoTro, isNot(contains(LbNgonNgu.gia)));
  });

  testWidgets('context.l10n đọc chuỗi theo Localizations', (tester) async {
    await tester.pumpWidget(
      Localizations(
        locale: LbNgonNgu.en,
        delegates: const [
          LbL10n.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: const _Doc(),
      ),
    );
    await tester.pump();
    expect(find.text('Map'), findsOneWidget);
  });

  testWidgets('chuỗi vi / en / en-XA khác nhau, placeholder giữ nguyên', (
    tester,
  ) async {
    final kq = <Locale, LbL10n>{};
    for (final l in [LbNgonNgu.vi, LbNgonNgu.en, LbNgonNgu.gia]) {
      kq[l] = await LbL10n.delegate.load(l);
    }
    expect(kq[LbNgonNgu.vi]!.tabSettings, 'Cài đặt');
    expect(kq[LbNgonNgu.en]!.tabSettings, 'Settings');
    expect(kq[LbNgonNgu.gia]!.tabSettings, startsWith('['));
    expect(kq[LbNgonNgu.vi]!.settingsVersion('1.2.3'), 'Phiên bản 1.2.3');
    expect(kq[LbNgonNgu.gia]!.settingsVersion('1.2.3'), contains('1.2.3'));
  });
}

class _Doc extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) =>
      Text(context.l10n.tabMap, textDirection: TextDirection.ltr);
}
