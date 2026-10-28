import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

/// Một kích thước màn hình (dp, dpr 1) trong ma trận golden.
typedef ManHinh = ({String ten, Size kichCo});

/// 12 kích thước phủ cả 3 breakpoint, dọc và ngang.
const manHinh12 = <ManHinh>[
  (ten: 'se-320x568', kichCo: Size(320, 568)),
  (ten: 'p-360x800', kichCo: Size(360, 800)),
  (ten: 'ip8-375x667', kichCo: Size(375, 667)),
  (ten: 'ip15-390x844', kichCo: Size(390, 844)),
  (ten: 'px-412x915', kichCo: Size(412, 915)),
  (ten: 'pm-430x932', kichCo: Size(430, 932)),
  (ten: 'ngang-640x360', kichCo: Size(640, 360)),
  (ten: 'tab7-600x960', kichCo: Size(600, 960)),
  (ten: 'mini-744x1133', kichCo: Size(744, 1133)),
  (ten: 'tab10-800x1280', kichCo: Size(800, 1280)),
  (ten: 'pro-1024x1366', kichCo: Size(1024, 1366)),
  (ten: 'ngang-1280x800', kichCo: Size(1280, 800)),
];

/// Cỡ chữ hệ thống thử (nhỏ, chuẩn, rất lớn).
const coChu3 = <double>[0.85, 1, 2];

/// Ngôn ngữ thử: vi, en và pseudo-locale (dài thêm ~40%).
const ngonNgu3 = <Locale>[LbNgonNgu.vi, LbNgonNgu.en, LbNgonNgu.gia];

/// Một ô của ma trận.
typedef OMaTran = ({
  ManHinh manHinh,
  Brightness sang,
  Locale ngonNgu,
  double coChu,
});

/// Mọi tổ hợp kích thước x theme x ngôn ngữ x cỡ chữ.
Iterable<OMaTran> toHop({
  List<ManHinh> dsManHinh = manHinh12,
  List<Brightness> dsSang = Brightness.values,
  List<Locale> dsNgonNgu = ngonNgu3,
  List<double> dsCoChu = coChu3,
}) sync* {
  for (final m in dsManHinh) {
    for (final s in dsSang) {
      for (final n in dsNgonNgu) {
        for (final c in dsCoChu) {
          yield (manHinh: m, sang: s, ngonNgu: n, coChu: c);
        }
      }
    }
  }
}

/// Đặt cửa sổ test theo [m] (dpr 1). Tự trả lại khi test kết thúc.
void datManHinh(WidgetTester tester, ManHinh m) {
  tester.view
    ..physicalSize = m.kichCo
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// MaterialApp tối giản quanh [con] với theme / ngôn ngữ / cỡ chữ của [o]
/// (dùng cho màn hình đơn lẻ trong package tính năng).
Widget khungThu(Widget con, {required OMaTran o}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LbTheme.light,
    darkTheme: LbTheme.dark,
    themeMode: o.sang == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: o.ngonNgu,
    supportedLocales: LbL10n.supportedLocales,
    localizationsDelegates: const [
      LbL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(o.coChu)),
      child: child!,
    ),
    home: con,
  );
}

/// Dựng từng ô của ma trận và đỏ ngay khi có lỗi bố cục (tràn, ràng buộc vô
/// hạn...). [dung] trả widget cho ô đó; [sauKhiDung] để kiểm thêm tuỳ ý.
Future<void> kiemMaTran(
  WidgetTester tester,
  Widget Function(OMaTran o) dung, {
  Iterable<OMaTran>? dsO,
  Future<void> Function(OMaTran o)? sauKhiDung,
}) async {
  for (final o in dsO ?? toHop()) {
    datManHinh(tester, o.manHinh);
    await tester.pumpWidget(dung(o));
    await tester.pump(const Duration(seconds: 2));
    final loi = tester.takeException();
    if (loi != null) {
      fail(
        'Lỗi bố cục ở ${o.manHinh.ten} ${o.sang.name} ${o.ngonNgu} '
        'x${o.coChu}: $loi',
      );
    }
    await sauKhiDung?.call(o);
    // Bỏ cây cũ để ô sau dựng lại từ đầu (không giữ state / hoạt ảnh).
    await tester.pumpWidget(const SizedBox.shrink());
  }
}

/// Tên tệp golden chuẩn cho một ô: `<ten>/<man-hinh>-<theme>-<locale>-<co>.png`.
String tenGolden(String ten, OMaTran o) =>
    'goldens/$ten/${o.manHinh.ten}-${o.sang.name}-${o.ngonNgu.toLanguageTag()}'
    '-x${o.coChu}.png';

/// Các ô được chụp ảnh golden (ma trận đủ chỉ kiểm bố cục, không lưu ảnh để
/// repo không phình): 3 breakpoint ở theme sáng / vi / x1, bản tối / en ở
/// compact, và trường hợp khó nhất (máy nhỏ nhất, pseudo-locale, chữ x2).
final oChup = <OMaTran>[
  for (final i in [3, 8, 11])
    (
      manHinh: manHinh12[i],
      sang: Brightness.light,
      ngonNgu: LbNgonNgu.vi,
      coChu: 1.0,
    ),
  (
    manHinh: manHinh12[3],
    sang: Brightness.dark,
    ngonNgu: LbNgonNgu.en,
    coChu: 1.0,
  ),
  (
    manHinh: manHinh12[0],
    sang: Brightness.dark,
    ngonNgu: LbNgonNgu.gia,
    coChu: 2.0,
  ),
];

/// Chụp golden mọi ô trong [dsO] (mặc định [oChup]) vào
/// `goldens/<ten>/...png`. Mỗi ô dựng lại cây từ đầu để theme / ngôn ngữ
/// không ở giữa hoạt ảnh chuyển.
Future<void> chupGolden(
  WidgetTester tester,
  String ten,
  Widget Function(OMaTran o) dung, {
  Iterable<OMaTran>? dsO,
  Finder? tim,
}) async {
  for (final o in dsO ?? oChup) {
    datManHinh(tester, o.manHinh);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(dung(o));
    await tester.pump(const Duration(seconds: 2));
    await expectLater(
      tim ?? find.byType(MaterialApp),
      matchesGoldenFile(tenGolden(ten, o)),
    );
  }
}
