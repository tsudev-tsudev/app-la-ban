import 'dart:io';

import 'package:app_shell/src/bang_an_toan.dart';
import 'package:app_shell/src/khoi_dong.dart';
import 'package:app_shell/src/luu_tru.dart';
import 'package:compass_feature/compass_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_feature/map_feature.dart';
import 'package:storage/storage.dart';
import 'package:test_kit/test_kit.dart';

import 'ho_tro.dart';

/// Thư mục thật bị chặn (không phải thư mục) -> kho không mở được.
class KhoHong implements KhoKhoa {
  @override
  Future<Never> layKhoaCsdl() => throw StateError('keystore');

  @override
  Future<Never> thuMucDuLieu() => throw StateError('nen tang');
}

void main() {
  setUpAll(napFontThat);
  late Directory tm;
  setUp(() => tm = Directory.systemTemp.createTempSync('an_toan'));
  tearDown(() => tm.deleteSync(recursive: true));

  Widget appAnToan(LyDoAnToan lyDo) =>
      appThu(them: [anToanProvider.overrideWithValue(lyDo)]);

  test('cờ tính năng: chế độ an toàn tắt hết, thường theo mặc định', () {
    final thuong = ProviderContainer();
    addTearDown(thuong.dispose);
    expect(thuong.read(coTinhNangProvider)[CoTinhNang.banDo], isTrue);
    expect(thuong.read(anToanProvider), isNull);
    final at = ProviderContainer(
      overrides: [anToanProvider.overrideWithValue(LyDoAnToan.migrationLoi)],
    );
    addTearDown(at.dispose);
    expect(at.read(coTinhNangProvider).values, everyElement(isFalse));
  });

  testWidgets('chạy thường: không có băng, bản đồ mở', (tester) async {
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(appThu());
    await tester.pumpAndSettle();
    expect(find.byType(BangAnToan), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tab/ban-do')));
    await tester.pumpAndSettle();
    expect(find.byType(ManBanDo), findsOneWidget);
  });

  testWidgets('an toàn: băng đúng lý do, bản đồ tạm tắt', (tester) async {
    datHeThong(tester, oChup.first);
    for (final (lyDo, chu) in [
      (LyDoAnToan.crashLienTiep, 'tạm tắt các tính năng mới'),
      (LyDoAnToan.migrationLoi, 'Dữ liệu cũ vẫn được giữ nguyên'),
      (LyDoAnToan.csdlMoiHon, 'phiên bản mới hơn'),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(appAnToan(lyDo));
      await tester.pumpAndSettle();
      expect(find.textContaining(chu), findsOneWidget);
      // Không có kho thật -> không có nút thử lại.
      expect(find.byKey(const ValueKey('thu-che-do-thuong')), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey('tab/ban-do')));
    await tester.pumpAndSettle();
    expect(find.byType(ManBanDo), findsNothing);
    expect(find.byType(ManTamTat), findsOneWidget);
    expect(find.text('Tính năng này đang tạm tắt.'), findsOneWidget);
  });

  testWidgets('ma trận: băng an toàn không tràn', (tester) async {
    await kiemMaTran(tester, (o) {
      datHeThong(tester, o);
      return appAnToan(LyDoAnToan.migrationLoi);
    });
  });

  testWidgets('golden: băng an toàn', (tester) async {
    await chupGolden(tester, 'an_toan', (o) {
      datHeThong(tester, o);
      return appAnToan(LyDoAnToan.crashLienTiep);
    });
  });

  testWidgets('dungApp: đọc cài đặt đã lưu trước khung đầu, đánh dấu ổn định '
      'sau 5 s', (tester) async {
    datHeThong(tester, oChup.first);
    TepJson.mo('${tm.path}/cai_dat.json')
        .ghiDongBo(caiDatDaXemJson({'ngonNgu': 'en'}));
    TepJson.mo('${tm.path}/la_ban.json').ghiDongBo({'bacThuc': false});
    final app = (await tester.runAsync(
      () => dungApp(
        cauHinhThuDev,
        khoKhoa: KhoKhoaBoNho(tm.path),
        nen: false,
        ghiDeThem: ghiDeThu,
      ),
    ))!;
    await tester.pumpWidget(app);
    await tester.pump();
    expect(find.text('Compass'), findsWidgets);
    final trangThai = '${tm.path}/trang_thai.json';
    expect(TepJson.mo(trangThai).duLieu['soLanChuaOnDinh'], 1);
    await tester.pump(const Duration(seconds: 5));
    expect(TepJson.mo(trangThai).duLieu['soLanChuaOnDinh'], 0);
    final vungChua = ProviderScope.containerOf(
      tester.element(find.text('Compass').first),
    );
    expect(vungChua.read(tuyChonLaBanProvider).bacThuc, isFalse);
    expect(find.text('Magnetic north'), findsOneWidget);
    final kho = vungChua.read(khoLuuTruProvider)!;
    expect(kho.csdl, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(kho.dong);
  });

  testWidgets('dungApp: kho lỗi -> vẫn chạy, chế độ an toàn', (tester) async {
    datHeThong(tester, oChup.first);
    final app = (await tester.runAsync(
      () => dungApp(
        cauHinhThuDev,
        khoKhoa: KhoHong(),
        nen: false,
        ghiDeThem: ghiDeThu,
      ),
    ))!;
    await tester.pumpWidget(app);
    await tester.pump(const Duration(seconds: 2));
    // Không có kho -> cài đặt trong bộ nhớ: qua màn giới thiệu rồi tới băng.
    await tester.tap(find.byKey(const ValueKey('bat-dau')));
    await tester.pumpAndSettle();
    expect(find.byType(BangAnToan), findsOneWidget);
    expect(find.textContaining('Dữ liệu cũ'), findsOne);
  });

  testWidgets('an toàn do crash: nút thử chế độ thường gỡ ghim', (
    tester,
  ) async {
    datHeThong(tester, oChup.first);
    TepJson.mo('${tm.path}/trang_thai.json').ghiDongBo(
      TrangThaiKhoiDong(
        anToanChoPhienBan: cauHinhThuDev.phienBan,
        lyDo: LyDoAnToan.crashLienTiep,
      ).toJson(),
    );
    TepJson.mo('${tm.path}/cai_dat.json').ghiDongBo(caiDatDaXemJson());
    final app = (await tester.runAsync(
      () => dungApp(
        cauHinhThuDev,
        khoKhoa: KhoKhoaBoNho(tm.path),
        nen: false,
        ghiDeThem: ghiDeThu,
      ),
    ))!;
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('thu-che-do-thuong')));
    await tester.pump();
    expect(find.text('Mở lại ứng dụng để áp dụng.'), findsOneWidget);
    expect(
      TrangThaiKhoiDong.tuJson(TepJson.mo('${tm.path}/trang_thai.json').duLieu),
      const TrangThaiKhoiDong(),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('theoDoiOnDinh: về nền sớm cũng tính ổn định, chỉ gọi 1 lần', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var dem = 0;
    theoDoiOnDinh(() => dem++);
    await tester.pump();
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(dem, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    expect(dem, 1);
  });
}
