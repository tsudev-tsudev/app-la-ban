import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:test_kit/test_kit.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

import 'thu_chung.dart';

final OMaTran o = (
  manHinh: manHinh12[3],
  sang: Brightness.light,
  ngonNgu: LbNgonNgu.vi,
  coChu: 1.0,
);

void main() {
  setUpAll(napFontThat);

  testWidgets('trợ năng: vùng chạm, nhãn, tương phản', (tester) async {
    await kiemTroNang(
      tester,
      (o) => dung(const ManDiem(), o, ghiDe(kho: KhoDiemBoNho(diemThu))),
    );
  });

  testWidgets('trống: ma trận không tràn', (tester) async {
    await kiemMaTran(tester, (o) => dung(const ManDiem(), o, ghiDe()));
  });

  testWidgets('trống: golden', (tester) async {
    await chupGolden(
      tester,
      'man_diem',
      (o) => dung(const ManDiem(), o, ghiDe()),
    );
  });

  testWidgets('có điểm: ma trận không tràn + golden', (tester) async {
    await kiemMaTran(
      tester,
      (o) => dung(const ManDiem(), o, ghiDe(kho: KhoDiemBoNho(diemThu))),
    );
    await chupGolden(
      tester,
      'man_diem_ds',
      (o) => dung(const ManDiem(), o, ghiDe(kho: KhoDiemBoNho(diemThu))),
    );
  });

  testWidgets('lưu vị trí hiện tại: tự điền toạ độ GPS, đặt tên gợi ý, lưu '
      'vào kho kèm ảnh', (tester) async {
    datManHinh(tester, o.manHinh);
    final kho = KhoDiemBoNho();
    final nt = NenTangGia()..anh = (duLieu: _png1x1, rong: 1, cao: 1);
    await tester.pumpWidget(
      dung(
        const ManDiem(),
        o,
        ghiDe(
          kho: kho,
          nenTang: nt,
          viTri: const ViTriCo((
            viDo: 21.0285111,
            kinhDo: 105.8521822,
            caoDo: 15.25,
            saiSoM: 6,
          )),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('luu-vi-tri')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('o-vi-do')))
          .controller!
          .text,
      '21.0285111',
    );
    expect(find.text('Điểm 1'), findsOneWidget);
    expect(find.text('Sai số vị trí ±6 m'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('them-anh')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('luu-diem')));
    await tester.tap(find.byKey(const ValueKey('luu-diem')));
    await tester.pumpAndSettle();
    final ds = await kho.tatCa();
    expect(ds.single.ten, 'Điểm 1');
    expect(ds.single.caoDo, 15.3);
    expect(ds.single.taoLuc, gioThu);
    expect((await kho.theoDoiAnh('id-0').first).single.rong, 1);
    expect(find.text('Điểm 1'), findsOneWidget);
  });

  testWidgets('nhập toạ độ tay: báo lỗi trường sai, không lưu', (tester) async {
    datManHinh(tester, o.manHinh);
    final kho = KhoDiemBoNho();
    await tester.pumpWidget(dung(const ManDiem(), o, ghiDe(kho: kho)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-diem')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập toạ độ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('o-ten')), ' ');
    await tester.enterText(find.byKey(const ValueKey('o-vi-do')), '95');
    await tester.enterText(find.byKey(const ValueKey('o-kinh-do')), '105,5');
    await tester.enterText(find.byKey(const ValueKey('o-cao-do')), '-');
    await tester.ensureVisible(find.byKey(const ValueKey('luu-diem')));
    await tester.tap(find.byKey(const ValueKey('luu-diem')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên điểm'), findsOneWidget);
    expect(find.text('Vĩ độ từ -90 đến 90'), findsOneWidget);
    expect(find.text('Cao độ không hợp lệ'), findsOneWidget);
    expect(find.text('Kinh độ từ -180 đến 180'), findsNothing);
    expect(await kho.tatCa(), isEmpty);
  });

  testWidgets('xuất GPX rồi nhập lại vào kho trống: đủ điểm, đúng dữ liệu', (
    tester,
  ) async {
    datManHinh(tester, o.manHinh);
    final nt = NenTangGia();
    await tester.pumpWidget(
      dung(const ManDiem(), o, ghiDe(kho: KhoDiemBoNho(diemThu), nenTang: nt)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-diem')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xuất GPX'));
    await tester.pumpAndSettle();
    expect(nt.luu.single.$1, 'la-ban-diem-20261030.gpx');
    expect(nt.luu.single.$2, 'application/gpx+xml');
    expect(find.text('Đã lưu tệp.'), findsOneWidget);

    final kho2 = KhoDiemBoNho();
    final nt2 = NenTangGia()..tepMo = utf8.encode(nt.luu.single.$3);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      dung(const ManDiem(), o, ghiDe(kho: kho2, nenTang: nt2)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-diem')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập GPX / KML'));
    // Đọc tệp ở isolate riêng: chờ thật.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pumpAndSettle();
    expect(await kho2.tatCa(), diemThu);
    expect(find.text('Đã thêm 2, cập nhật 0, bỏ qua 0 điểm.'), findsOneWidget);
  });

  testWidgets('nhập tệp hỏng -> báo lỗi', (tester) async {
    datManHinh(tester, o.manHinh);
    final nt = NenTangGia()..tepMo = utf8.encode('<html></html>');
    await tester.pumpWidget(dung(const ManDiem(), o, ghiDe(nenTang: nt)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-diem')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập GPX / KML'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Không đọc được tệp: không phải GPX / KML hợp lệ.'),
      findsOneWidget,
    );
  });

  testWidgets('chi tiết: sửa tên, rồi xoá có xác nhận', (tester) async {
    datManHinh(tester, o.manHinh);
    final kho = KhoDiemBoNho(diemThu);
    await tester.pumpWidget(dung(const ManDiem(), o, ghiDe(kho: kho)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ Gươm'));
    await tester.pumpAndSettle();
    expect(find.text('Gặp ở cổng đền Ngọc Sơn'), findsOneWidget);
    expect(find.text('Cao độ 12,3 m'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sua-diem')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('o-ten')), 'Hồ Hoàn Kiếm');
    await tester.ensureVisible(find.byKey(const ValueKey('luu-diem')));
    await tester.tap(find.byKey(const ValueKey('luu-diem')));
    await tester.pumpAndSettle();
    expect(find.text('Hồ Hoàn Kiếm'), findsWidgets);
    final sua = (await kho.tatCa()).firstWhere((d) => d.id == 'a');
    expect(
      (sua.ten, sua.taoLuc, sua.viDo),
      ('Hồ Hoàn Kiếm', gioThu, 21.0285111),
    );

    await tester.tap(find.byKey(const ValueKey('xoa-diem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('xac-nhan-xoa')));
    await tester.pumpAndSettle();
    expect((await kho.tatCa()).map((d) => d.id), ['b']);
    expect(find.byType(ManDiem), findsOneWidget);
  });

  testWidgets('chế độ an toàn: đọc thô + xuất GPX', (tester) async {
    datManHinh(tester, o.manHinh);
    final nt = NenTangGia();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...ghiDe(nenTang: nt, khongKho: true),
          docDiemAnToanProvider.overrideWithValue(() async => diemThu),
        ],
        child: khungThu(const ManDiem(), o: o),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 điểm'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('xuat-an-toan')));
    await tester.pumpAndSettle();
    expect(nhapTep(nt.luu.single.$3).diem.map((d) => d.id), ['a', 'b']);
  });

  testWidgets('chế độ an toàn: ma trận không tràn + golden; đọc lỗi -> báo', (
    tester,
  ) async {
    List<Override> ds(OMaTran _) => [
      ...ghiDe(khongKho: true),
      docDiemAnToanProvider.overrideWithValue(() async => diemThu),
    ];
    await kiemMaTran(
      tester,
      (o) => ProviderScope(
        overrides: ds(o),
        child: khungThu(const ManDiem(), o: o),
      ),
    );
    await chupGolden(
      tester,
      'man_diem_an_toan',
      (o) => ProviderScope(
        overrides: ds(o),
        child: khungThu(const ManDiem(), o: o),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...ghiDe(khongKho: true),
          docDiemAnToanProvider.overrideWithValue(
            () async => throw StateError('khoá'),
          ),
        ],
        child: khungThu(const ManDiem(), o: o),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không đọc được điểm đã lưu.'), findsOneWidget);
  });
}

/// PNG 1x1 hợp lệ (ảnh thu nhỏ giả).
final Uint8List _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/'
  'iZk9HQAAAABJRU5ErkJggg==',
);
