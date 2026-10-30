import 'package:compass_feature/compass_feature.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:la_ban/src/app.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/gioi_thieu.dart';
import 'package:la_ban/src/router.dart';
import 'package:la_ban/src/tab_app.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:test_kit/test_kit.dart';

import 'ho_tro.dart';

/// Đếm số lần build; không phụ thuộc Theme / Localizations.
class _DoBuild extends StatefulWidget {
  const new(this.ten);

  final String ten;
  static final soLan = <String, int>{};
  static final state = <String, State>{};

  @override
  State<_DoBuild> createState() => _DoBuildState();
}

class _DoBuildState extends State<_DoBuild> {
  @override
  Widget build(BuildContext context) {
    _DoBuild.soLan.update(widget.ten, (n) => n + 1, ifAbsent: () => 1);
    _DoBuild.state[widget.ten] = this;
    return const SizedBox.expand();
  }
}

final Override _tabDo = dsTabProvider.overrideWith(
  (ref) => [
    for (final (i, d) in ['/a', '/b', '/c', '/d'].indexed)
      (
        duongDan: d,
        icon: LbIcons.all[i],
        nhan: (LbL10n l) =>
            [l.tabCompass, l.tabMap, l.tabWaypoints, l.tabSettings][i],
        man: _DoBuild(d),
      ),
  ],
);

void main() {
  setUpAll(napFontThat);

  testWidgets('lần đầu: giới thiệu -> Bắt đầu -> tab La bàn', (tester) async {
    datManHinh(tester, manHinh12[3]);
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(appThu(daXem: false));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(ManGioiThieu), findsOneWidget);
    expect(find.byType(LbLogoDong), findsOneWidget);
    expect(find.text('Chào mừng đến với La bàn'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bat-dau')));
    await tester.pumpAndSettle();
    expect(find.byType(ManGioiThieu), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(ManLaBan), findsOneWidget);
    expect(find.textContaining('42,0°'), findsOneWidget);
  });

  testWidgets('đổi ngôn ngữ / theme: giữ tab + state, không dựng lại màn', (
    tester,
  ) async {
    _DoBuild.soLan.clear();
    _DoBuild.state.clear();
    datManHinh(tester, manHinh12[3]);
    datHeThong(tester, oChup.first);
    final c = ProviderContainer(
      overrides: [
        caiDatProvider.overrideWith(CaiDatDaXem.new),
        ...ghiDeThu,
        _tabDo,
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const LaBanApp(flavor: Flavor.dev),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bản đồ'));
    await tester.pumpAndSettle();
    final router = c.read(routerProvider);
    expect(router.state.matchedLocation, '/b');
    final stateB = _DoBuild.state['/b'];
    final lanB = _DoBuild.soLan['/b'];
    final lanA = _DoBuild.soLan['/a'];

    c.read(caiDatProvider.notifier).datNgonNgu(LuaChonNgonNgu.en);
    await tester.pumpAndSettle();
    expect(find.text('Map'), findsOneWidget);
    c.read(caiDatProvider.notifier).datCheDo(CheDoGiaoDien.toi);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );

    expect(identical(c.read(routerProvider), router), isTrue);
    expect(router.state.matchedLocation, '/b');
    expect(identical(_DoBuild.state['/b'], stateB), isTrue);
    expect(_DoBuild.soLan['/b'], lanB);
    expect(_DoBuild.soLan['/a'], lanA);

    // Quay lại tab đầu: state tab A vẫn còn (indexedStack).
    await tester.tap(find.text('Compass'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/a');
  });

  testWidgets('điều hướng đủ 4 tab bằng thanh dưới', (tester) async {
    datManHinh(tester, manHinh12[3]);
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(appThu());
    await tester.pumpAndSettle();
    for (final (nhan, dau) in [
      ('Bản đồ', find.byTooltip('Bản đồ ngoại tuyến')),
      ('Điểm', find.text('Chưa có điểm nào')),
      ('Cài đặt', find.text('Ngôn ngữ')),
    ]) {
      await tester.tap(find.byKey(ValueKey(_khoaTab(nhan))));
      await tester.pumpAndSettle();
      expect(dau, findsOneWidget, reason: nhan);
    }
  });

  testWidgets('rail ở medium / expanded, thanh dưới ở compact', (tester) async {
    for (final (i, ray, moRong) in [
      (3, false, false),
      (7, true, false),
      (11, true, true),
    ]) {
      datManHinh(tester, manHinh12[i]);
      datHeThong(tester, oChup.first);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(appThu());
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), ray ? findsOneWidget : findsNothing);
      expect(find.byType(NavigationBar), ray ? findsNothing : findsOneWidget);
      if (ray) {
        final r = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(r.extended, moRong);
        await tester.tap(find.byKey(const ValueKey('tab/diem')));
        await tester.pumpAndSettle();
        expect(find.text('Chưa có điểm nào'), findsOneWidget);
      }
    }
  });

  testWidgets('ma trận: giới thiệu + khung 4 tab không tràn', (tester) async {
    await kiemMaTran(tester, (o) {
      datHeThong(tester, o);
      return appThu(daXem: false);
    });
    final tabs = ['/la-ban', '/ban-do', '/diem', '/cai-dat'];
    await kiemMaTran(
      tester,
      (o) {
        datHeThong(tester, o);
        return appThu();
      },
      sauKhiDung: (o) async {
        for (final t in tabs) {
          await tester.tap(find.byKey(ValueKey('tab$t')));
          await tester.pump(const Duration(seconds: 1));
          final loi = tester.takeException();
          if (loi != null) fail('Tràn ở $t ${o.manHinh.ten}: $loi');
        }
      },
    );
  });

  testWidgets('golden: khung app + giới thiệu', (tester) async {
    await chupGolden(tester, 'khung_app', (o) {
      datHeThong(tester, o);
      return appThu();
    });
    await chupGolden(tester, 'gioi_thieu', (o) {
      datHeThong(tester, o);
      return appThu(daXem: false);
    });
  });

  testWidgets('tiêu đề cửa sổ theo flavor / ngôn ngữ', (tester) async {
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(appThu(khoDiem: false));
    await tester.pumpAndSettle();
    final t = tester.widget<Title>(find.byType(Title));
    expect(t.title, 'La bàn DEV');
    final prod = ProviderScope(
      overrides: [caiDatProvider.overrideWith(CaiDatDaXem.new), ...ghiDeThu],
      child: const LaBanApp(flavor: Flavor.prod),
    );
    await tester.pumpWidget(prod);
    await tester.pumpAndSettle();
    expect(tester.widget<Title>(find.byType(Title)).title, 'La bàn');
  });
}

String _khoaTab(String nhan) => switch (nhan) {
  'Bản đồ' => 'tab/ban-do',
  'Điểm' => 'tab/diem',
  _ => 'tab/cai-dat',
};
