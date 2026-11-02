import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:test_kit/test_kit.dart';

/// Ghi lại thao tác của màn để kiểm.
final class _Ghi {
  int xuat = 0;
  int xoa = 0;
  int caiDat = 0;
  final mo = <Uri>[];
  bool xuatDuoc = true;
  bool moDuoc = true;

  HanhDongRiengTu get hanhDong => HanhDongRiengTu(
    demDiem: () async => 3,
    xuatDuLieu: () async {
      xuat++;
      return xuatDuoc;
    },
    xoaToanBo: () async => xoa++,
    maThietBi: () => 'dv_123',
    moLienKet: (u) async {
      mo.add(u);
      return moDuoc;
    },
    moCaiDatHeThong: () async => caiDat++,
  );
}

/// Cuộn tới mục rồi đưa hẳn vào giữa vùng nhìn (sát mép thì tap trượt).
Future<void> _toi(WidgetTester tester, String khoa) async {
  final f = find.byKey(ValueKey(khoa));
  await tester.scrollUntilVisible(f, 100);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(napFontThat);

  final dongY = DongYXuLy(
    ban: banThongBaoDuLieu,
    trucTuyen: true,
    luc: DateTime.utc(2026, 10, 30, 8),
  );

  Widget dung(OMaTran o, {_Ghi? ghi, CaiDat? caiDat}) => ProviderScope(
    overrides: [
      hanhDongRiengTuProvider.overrideWithValue((ghi ?? _Ghi()).hanhDong),
      khoCaiDatProvider.overrideWithValue(
        KhoCaiDatBoNho(caiDat ?? CaiDat(daXemGioiThieu: true, dongY: dongY)),
      ),
    ],
    child: khungThu(const ManQuyenRiengTu(), o: o),
  );

  testWidgets('trợ năng: vùng chạm, nhãn, tương phản', (tester) async {
    await kiemTroNang(tester, dung);
  });

  testWidgets('ma trận 12 kích thước x theme x ngôn ngữ x cỡ chữ: không tràn', (
    tester,
  ) async {
    await kiemMaTran(tester, dung);
  });

  testWidgets('golden', (tester) async {
    await chupGolden(tester, 'man_quyen_rieng_tu', dung);
  });

  testWidgets('không nối nền tảng: chỉ còn thông báo + công tắc', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(child: khungThu(const ManQuyenRiengTu(), o: oChup.first)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('truc-tuyen')), findsOneWidget);
    expect(find.byKey(const ValueKey('chinh-sach')), findsNothing);
    expect(find.byKey(const ValueKey('xuat')), findsNothing);
    expect(find.byKey(const ValueKey('xoa-het')), findsNothing);
    expect(find.byKey(const ValueKey('yeu-cau-xoa')), findsNothing);
    expect(find.byKey(const ValueKey('cai-dat-he-thong')), findsNothing);
    expect(find.byKey(const ValueKey('bao-loi')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Thiết bị chưa đăng ký với máy chủ'),
      120,
    );
    expect(find.text('Thiết bị chưa đăng ký với máy chủ'), findsOneWidget);
    // Chưa trả lời -> công tắc tắt, không có dòng thời điểm.
    expect(find.textContaining('Lựa chọn ghi lúc'), findsNothing);
  });

  testWidgets('tắt công tắc = rút đồng ý, bật lại = đồng ý', (tester) async {
    final c = ProviderContainer(
      overrides: [
        hanhDongRiengTuProvider.overrideWithValue(_Ghi().hanhDong),
        khoCaiDatProvider.overrideWithValue(
          KhoCaiDatBoNho(CaiDat(daXemGioiThieu: true, dongY: dongY)),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: khungThu(const ManQuyenRiengTu(), o: oChup.first),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Lựa chọn ghi lúc'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('truc-tuyen')));
    await tester.pump();
    expect(c.read(caiDatProvider).trucTuyen, isFalse);
    expect(c.read(caiDatProvider).dongY!.trucTuyen, isFalse);
    await tester.tap(find.byKey(const ValueKey('truc-tuyen')));
    await tester.pump();
    expect(c.read(caiDatProvider).trucTuyen, isTrue);
    // S10b: báo cáo sự cố mặc định tắt, bật riêng; rút đồng ý trực tuyến thì
    // công tắc khoá + không gửi dù cờ còn lưu.
    expect(c.read(caiDatProvider).guiBaoLoi, isFalse);
    await tester.tap(find.byKey(const ValueKey('bao-loi')));
    await tester.pump();
    expect(c.read(caiDatProvider).guiBaoLoi, isTrue);
    await tester.tap(find.byKey(const ValueKey('truc-tuyen')));
    await tester.pump();
    expect(c.read(caiDatProvider).guiBaoLoi, isFalse);
    expect(
      find.text('Cần bật Kết nối bảo mật trực tuyến trước.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('bao-loi')));
    await tester.pump();
    expect(c.read(caiDatProvider).baoLoi, isTrue);
    await tester.scrollUntilVisible(find.text('3 điểm mốc đã lưu'), 120);
    expect(find.text('3 điểm mốc đã lưu'), findsOneWidget);
  });

  testWidgets('xuất dữ liệu báo kết quả', (tester) async {
    final g = _Ghi();
    await tester.pumpWidget(dung(oChup.first, ghi: g));
    await tester.pumpAndSettle();
    await _toi(tester, 'xuat');
    await tester.tap(find.byKey(const ValueKey('xuat')));
    await tester.pumpAndSettle();
    expect(g.xuat, 1);
    expect(find.text('Đã lưu tệp dữ liệu'), findsOneWidget);
    g.xuatDuoc = false;
    await tester.tap(find.byKey(const ValueKey('xuat')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu tệp dữ liệu'), findsOneWidget);
  });

  testWidgets('xoá toàn bộ cần xác nhận', (tester) async {
    final g = _Ghi();
    await tester.pumpWidget(dung(oChup.first, ghi: g));
    await tester.pumpAndSettle();
    await _toi(tester, 'xoa-het');
    await tester.tap(find.byKey(const ValueKey('xoa-het')));
    await tester.pumpAndSettle();
    expect(find.text('Xoá toàn bộ dữ liệu?'), findsOneWidget);
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(g.xoa, 0);
    await tester.tap(find.byKey(const ValueKey('xoa-het')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('xac-nhan-xoa')));
    await tester.pumpAndSettle();
    expect(g.xoa, 1);
  });

  testWidgets('chép mã thiết bị, thư yêu cầu xoá, chính sách, cài đặt', (
    tester,
  ) async {
    final chep = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          chep.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final g = _Ghi()..moDuoc = false;
    await tester.pumpWidget(dung(oChup.first, ghi: g));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chinh-sach')));
    await tester.pump();
    expect(
      g.mo.single.toString(),
      'https://compass.tsudev.com/quyen-rieng-tu/',
    );

    await _toi(tester, 'ma-thiet-bi');
    expect(find.text('Mã thiết bị: dv_123'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ma-thiet-bi')));
    await tester.pumpAndSettle();
    expect(chep, ['dv_123']);
    expect(find.text('Đã chép mã thiết bị'), findsOneWidget);

    await _toi(tester, 'yeu-cau-xoa');
    await tester.tap(find.byKey(const ValueKey('yeu-cau-xoa')));
    await tester.pumpAndSettle();
    final thu = g.mo.last;
    expect(thu.path, thuRiengTu);
    expect(thu.queryParameters['body'], contains('dv_123'));
    expect(
      find.text('Không mở được ứng dụng thư - hãy gửi tới privacy@tsudev.com'),
      findsOneWidget,
    );

    // Snackbar che mục cuối.
    ScaffoldMessenger.of(tester.element(find.byType(ManQuyenRiengTu)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await _toi(tester, 'cai-dat-he-thong');
    await tester.tap(find.byKey(const ValueKey('cai-dat-he-thong')));
    await tester.pump();
    expect(g.caiDat, 1);
  });

  testWidgets('tab Cài đặt mở màn Quyền riêng tư', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: khungThu(const ManCaiDat(phienBan: '1.0.0'), o: oChup.first),
      ),
    );
    await _toi(tester, 'quyen-rieng-tu');
    await tester.tap(find.byKey(const ValueKey('quyen-rieng-tu')));
    await tester.pumpAndSettle();
    expect(find.byType(ManQuyenRiengTu), findsOneWidget);
  });
}
