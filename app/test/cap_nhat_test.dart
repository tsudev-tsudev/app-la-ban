import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:la_ban/src/cap_nhat.dart';
import 'package:la_ban/src/kenh.dart';
import 'package:la_ban/src/luu_tru.dart';
import 'package:network/network.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';
import 'package:test_kit/test_kit.dart';

import 'ho_tro.dart';

CauHinhTuXa cauHinh({int toiThieu = 1, int khuyenNghi = 1, Set<String>? tat}) =>
    CauHinhTuXa(
      phatHanh: 1,
      het: 1 << 52,
      toiThieu: toiThieu,
      khuyenNghi: khuyenNghi,
      tat: tat ?? const {},
      pin: [for (final g in gocTinCay) g.pin],
      gocThem: const [],
    );

const tinhTrang = TinhTrangThietBi(
  trangThai: TrangThaiThietBi.clean,
  mucTin: MucTin.device,
  banMoi: (phienBan: '9.9.9-beta.9', maPhienBan: 999),
);

void main() {
  setUpAll(napFontThat);

  Widget app({CauHinhTuXa? ch, TinhTrangThietBi? tt}) => appThu(
    them: [
      cauHinhTuXaProvider.overrideWithValue(ch),
      tinhTrangProvider.overrideWithValue(tt),
    ],
  );

  test('mức cập nhật theo build của bản đang chạy', () {
    CapNhat muc({CauHinhTuXa? ch, TinhTrangThietBi? tt}) {
      final c = ProviderContainer(
        overrides: [
          cauHinhTuXaProvider.overrideWithValue(ch),
          tinhTrangProvider.overrideWithValue(tt),
        ],
      );
      addTearDown(c.dispose);
      return c.read(capNhatProvider);
    }

    expect(muc(), CapNhat.khong);
    expect(muc(ch: cauHinh(toiThieu: 999)), CapNhat.batBuoc);
    expect(muc(ch: cauHinh(khuyenNghi: 999)), CapNhat.khuyenNghi);
    expect(muc(tt: tinhTrang), CapNhat.khuyenNghi);
  });

  test('kill-switch từ Remote Config tắt cờ tương ứng', () {
    final c = ProviderContainer(
      overrides: [
        cauHinhTuXaProvider.overrideWithValue(cauHinh(tat: {'ban-do', 'ar'})),
      ],
    );
    addTearDown(c.dispose);
    final co = c.read(coTinhNangProvider);
    expect(co[CoTinhNang.banDo], isFalse);
    expect(co[CoTinhNang.ar], isFalse);
    expect(co[CoTinhNang.chiaSe], isTrue);
  });

  test('trang tải theo ngôn ngữ', () {
    expect(trangTaiVe(const Locale('vi')).path, '/tai-ve');
    expect(trangTaiVe(const Locale('en')).path, '/en/download');
  });

  testWidgets('không cần cập nhật: không có băng / màn chặn', (tester) async {
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(BangCapNhat), findsNothing);
    expect(find.byType(ManCapNhatBatBuoc), findsNothing);
  });

  testWidgets('bắt buộc: chỉ còn màn chặn', (tester) async {
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(app(ch: cauHinh(toiThieu: 999)));
    await tester.pumpAndSettle();
    expect(find.byType(ManCapNhatBatBuoc), findsOneWidget);
    expect(find.text('Cần cập nhật ứng dụng'), findsOneWidget);
    expect(find.byKey(const ValueKey('tab/ban-do')), findsNothing);
  });

  testWidgets('khuyến nghị: băng có số phiên bản, "Để sau" ẩn trong phiên', (
    tester,
  ) async {
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(app(tt: tinhTrang));
    await tester.pumpAndSettle();
    expect(find.textContaining('9.9.9-beta.9'), findsOneWidget);
    expect(find.byKey(const ValueKey('tab/ban-do')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cap-nhat-de-sau')));
    await tester.pumpAndSettle();
    expect(find.byType(BangCapNhat), findsNothing);
  });

  testWidgets('không mở được trình duyệt -> SnackBar chỉ đường', (
    tester,
  ) async {
    datHeThong(tester, oChup.first);
    Uri? daMo;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          LbL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LbNgonNgu.hoTro,
        locale: const Locale('vi'),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => moTrangTai(
                c,
                mo: (u) async {
                  daMo = u;
                  return false;
                },
              ),
              child: const Text('x'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('x'));
    await tester.pumpAndSettle();
    expect(daMo?.path, '/tai-ve');
    expect(find.textContaining('compass.tsudev.com/tai-ve'), findsOneWidget);
  });

  testWidgets('ma trận: màn chặn + băng gợi ý không tràn', (tester) async {
    await kiemMaTran(tester, (o) {
      datHeThong(tester, o);
      return app(ch: cauHinh(toiThieu: 999));
    });
    await kiemMaTran(tester, (o) {
      datHeThong(tester, o);
      return app(tt: tinhTrang);
    });
  });

  testWidgets('golden: cập nhật bắt buộc / gợi ý', (tester) async {
    await chupGolden(tester, 'cap_nhat_bat_buoc', (o) {
      datHeThong(tester, o);
      return app(ch: cauHinh(toiThieu: 999));
    });
    await chupGolden(tester, 'cap_nhat_goi_y', (o) {
      datHeThong(tester, o);
      return app(tt: tinhTrang);
    });
  });
}
