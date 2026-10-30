import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/app.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/gioi_thieu.dart';
import 'package:la_ban/src/khoi_dong.dart';
import 'package:la_ban/src/phien_ban.dart';
import 'package:la_ban/src/router.dart';
import 'package:location_feature/location_feature.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:storage/storage.dart';
import 'package:test_kit/test_kit.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

import 'ho_tro.dart';

const diem = DiemMoc(
  id: 'x',
  ten: 'Hồ Gươm',
  viDo: 21.0285111,
  kinhDo: 105.8521822,
  caoDo: 12.3,
  ghiChu: 'Cổng đền Ngọc Sơn',
  taoLuc: 0,
  suaLuc: 0,
);

void main() {
  setUpAll(napFontThat);
  late Directory tm;
  late KhoKhoa khoKhoa;
  setUp(() {
    tm = Directory.systemTemp.createTempSync('diem');
    khoKhoa = KhoKhoaBoNho(tm.path);
  });
  tearDown(() => tm.deleteSync(recursive: true));

  final token = maHoaToken(
    diem,
    hetHan: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
  );

  /// App thật (dungApp: CSDL mã hoá ở thư mục tạm, nối tab Điểm).
  Future<Widget> app({bool daXem = true}) => dungApp(
    Flavor.dev,
    khoKhoa: khoKhoa,
    nen: false,
    ghiDeThem: [
      if (daXem) caiDatProvider.overrideWith(CaiDatDaXem.new),
      huongThu,
      nguonViTriProvider.overrideWithValue(
        NguonViTriGhiSan([
          DocViTri(
            viDo: 21.024304,
            kinhDo: 105.857629,
            luc: DateTime.utc(2026, 10, 30),
            doCaoMucBien: 10,
            doChinhXacNgang: 5,
          ),
        ]),
      ),
    ],
  );

  /// Qua mốc "ổn định" 5 s của dungApp (không để Timer treo khi hết test).
  Future<void> xong(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    // Drift dọn stream query bằng timer 0 s sau khi huỷ nghe (bất đồng bộ).
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  ProviderContainer chua(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LaBanApp)));

  testWidgets('deep link /w/<token>: xem điểm -> lưu vào CSDL mã hoá -> tab '
      'Điểm có điểm', (tester) async {
    datManHinh(tester, manHinh12[3]);
    datHeThong(tester, oChup.first);
    await tester.pumpWidget((await tester.runAsync(app))!);
    await tester.pumpAndSettle();
    chua(tester).read(routerProvider).go('/w/$token');
    await tester.pumpAndSettle();
    expect(find.byType(ManNhanDiem), findsOneWidget);
    expect(find.text('Hồ Gươm'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('luu-diem-nhan')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(chua(tester).read(routerProvider).state.matchedLocation, '/diem');
    expect(find.text('Hồ Gươm'), findsOneWidget);
    final kho = chua(tester).read(khoDiemProvider)!;
    final ds = await tester.runAsync(kho.tatCa);
    expect(ds!.single.ghiChu, 'Cổng đền Ngọc Sơn');
    expect(kho, isA<KhoDiemDrift>());
    await xong(tester);
  });

  testWidgets('deep link khi chưa xem giới thiệu: vẫn mở màn điểm; link lạ '
      '-> tab đầu', (tester) async {
    datManHinh(tester, manHinh12[3]);
    datHeThong(tester, oChup.first);
    await tester.pumpWidget((await tester.runAsync(() => app(daXem: false)))!);
    await tester.pumpAndSettle();
    expect(find.byType(ManGioiThieu), findsOneWidget);
    chua(tester).read(routerProvider).go('/w/$token');
    await tester.pumpAndSettle();
    expect(find.byType(ManNhanDiem), findsOneWidget);
    await xong(tester);

    await tester.pumpWidget(appThu());
    await tester.pumpAndSettle();
    chua(tester).read(routerProvider).go('/khong-co/abc');
    await tester.pumpAndSettle();
    expect(chua(tester).read(routerProvider).state.matchedLocation, '/la-ban');
  });

  testWidgets('lưu vị trí GPS từ location_feature (cao độ mực biển, sai số)', (
    tester,
  ) async {
    datManHinh(tester, manHinh12[3]);
    datHeThong(tester, oChup.first);
    await tester.pumpWidget((await tester.runAsync(app))!);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab/diem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('luu-vi-tri')));
    await tester.pumpAndSettle();
    expect(find.text('Sai số vị trí ±5 m'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('o-cao-do')))
          .controller!
          .text,
      '10.0',
    );
    await xong(tester);
  });

  testWidgets('chế độ an toàn (crash liên tiếp): tab Điểm chỉ còn xuất, đọc '
      'thô được điểm cũ', (tester) async {
    // Lần chạy thường: lưu 1 điểm.
    final k = khoKhoa;
    final kho = await KhoLuuTru.mo(
      phienBanApp: phienBanApp,
      khoKhoa: k,
      nen: false,
    );
    await KhoDiemDrift(kho.csdl!).luu(diem);
    await kho.dong();
    for (var i = 0; i < 3; i++) {
      await (await KhoLuuTru.mo(
        phienBanApp: phienBanApp,
        khoKhoa: k,
        nen: false,
      )).dong();
    }
    datManHinh(tester, manHinh12[3]);
    datHeThong(tester, oChup.first);
    await tester.pumpWidget((await tester.runAsync(app))!);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab/diem')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Xuất điểm đã lưu'), findsOneWidget);
    expect(find.text('1 điểm'), findsOneWidget);
    await xong(tester);
  });
}
