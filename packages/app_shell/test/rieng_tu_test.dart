import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_shell/src/app.dart';
import 'package:app_shell/src/cong_truc_tuyen.dart';
import 'package:app_shell/src/dinh_danh.dart';
import 'package:app_shell/src/gioi_thieu.dart';
import 'package:app_shell/src/rieng_tu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:storage/storage.dart';
import 'package:test_kit/test_kit.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

import 'ho_tro.dart';

/// Nền tảng tab Điểm giả: chỉ ghi lại tệp được lưu.
final class _NenTang implements NenTangDiem {
  final tep = <(String, String, Uint8List)>[];

  @override
  Future<bool> luuTep(String tenGoiY, String mime, Uint8List duLieu) async {
    tep.add((tenGoiY, mime, duLieu));
    return true;
  }

  @override
  Future<AnhMoi?> chonAnh() async => null;

  @override
  Future<Uint8List?> moTep() async => null;

  @override
  Future<void> chiaSeChu(String chu, {required String tieuDe}) async {}
}

void main() {
  group('CongTrucTuyen', () {
    test('khiMo: đang mở chạy ngay, một lần', () {
      var n = 0;
      final c = CongTrucTuyen(mo: true)..khiMo(() => n++);
      expect(n, 1);
      c
        ..value = false
        ..value = true;
      expect(n, 1);
    });

    test('khiMo: đóng -> chờ tới lần mở đầu, rồi thôi nghe', () {
      var n = 0;
      final c = CongTrucTuyen(mo: false)..khiMo(() => n++);
      expect(n, 0);
      c.value = true;
      expect(n, 1);
      c
        ..value = false
        ..value = true;
      expect(n, 1);
    });
  });

  test('diemXuat: thời điểm ISO 8601 UTC, đủ trường', () {
    final d = diemXuat((
      id: 'a',
      ten: 'Hồ Gươm',
      viDo: 21.0287,
      kinhDo: 105.8524,
      caoDo: null,
      ghiChu: '',
      taoLuc: DateTime.utc(2026, 10, 30, 1).millisecondsSinceEpoch,
      suaLuc: DateTime.utc(2026, 10, 30, 2).millisecondsSinceEpoch,
    ));
    expect(d, {
      'id': 'a',
      'ten': 'Hồ Gươm',
      'viDo': 21.0287,
      'kinhDo': 105.8524,
      'caoDo': null,
      'ghiChu': '',
      'taoLuc': '2026-10-30T01:00:00.000Z',
      'suaLuc': '2026-10-30T02:00:00.000Z',
    });
  });

  group('noiRiengTu với kho thật', () {
    late Directory tm;
    setUp(() => tm = Directory.systemTemp.createTempSync('rieng_tu'));
    tearDown(() => tm.deleteSync(recursive: true));

    test('xuất JSON gồm cài đặt + điểm; xoá gọi đúng hàm; không có '
        'kho -> ẩn nút', () async {
      final kho = await KhoLuuTru.mo(
        phienBanApp: '0.1.0',
        khoKhoa: KhoKhoaBoNho(tm.path),
        nen: false,
      );
      addTearDown(kho.dong);
      await KhoDiemDrift(kho.csdl!).luu(
        const DiemMoc(
          id: 'a',
          ten: 'Điểm A',
          viDo: 21,
          kinhDo: 105,
          taoLuc: 1,
          suaLuc: 1,
        ),
      );
      await kho.caiDat.ghi(caiDatDaXemJson());
      final nt = _NenTang();
      var xoa = 0;
      final c = ProviderContainer(
        overrides: [
          ...noiRiengTu(kho, nenTang: nt, xoaToanBo: () async => xoa++),
        ],
      );
      addTearDown(c.dispose);
      final hd = c.read(hanhDongRiengTuProvider);
      expect(await hd.demDiem!(), 1);
      expect(hd.maThietBi, isNull, reason: 'chưa có dịch vụ định danh');
      expect(await hd.xuatDuLieu!(), isTrue);
      final (ten, mime, byte) = nt.tep.single;
      expect(ten, matches(RegExp(r'^la-ban-du-lieu-\d{8}\.json$')));
      expect(mime, 'application/json');
      final j = jsonDecode(utf8.decode(byte)) as Map<String, Object?>;
      expect(j['dinhDang'], dinhDangXuat);
      expect(j['phienBanApp'], isNotEmpty);
      expect((j['caiDat']! as Map)['daXemGioiThieu'], isTrue);
      expect((j['diem']! as List).single, containsPair('ten', 'Điểm A'));
      expect(j.containsKey('maThietBi'), isFalse);
      await hd.xoaToanBo!();
      expect(xoa, 1);

      final c2 = ProviderContainer(overrides: noiRiengTu(null));
      addTearDown(c2.dispose);
      final hd2 = c2.read(hanhDongRiengTuProvider);
      expect(hd2.demDiem, isNull);
      expect(hd2.xuatDuLieu, isNull);
      expect(hd2.xoaToanBo, isNull);
      expect(hd2.moLienKet, isNotNull);
      expect(hd2.moCaiDatHeThong, isNotNull);
      expect(c2.read(dichVuDinhDanhProvider), isNull);
    });
  });

  group('màn giới thiệu + cổng', () {
    setUpAll(napFontThat);

    testWidgets('chỉ dùng ngoại tuyến: vào app, cổng vẫn đóng; bật ở Quyền '
        'riêng tư -> cổng mở ngay', (tester) async {
      datManHinh(tester, manHinh12[3]);
      datHeThong(tester, oChup.first);
      final cong = CongTrucTuyen(mo: false);
      await tester.pumpWidget(
        appThu(
          daXem: false,
          them: [congTrucTuyenProvider.overrideWithValue(cong)],
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ManGioiThieu), findsOneWidget);
      expect(find.text('Dữ liệu của bạn'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ngoai-tuyen')));
      await tester.pumpAndSettle();
      expect(find.byType(ManGioiThieu), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(cong.value, isFalse);

      final c = ProviderScope.containerOf(
        tester.element(find.byType(LaBanApp)),
      );
      expect(c.read(caiDatProvider).dongY!.trucTuyen, isFalse);
      c.read(caiDatProvider.notifier).datDongY(trucTuyen: true);
      await tester.pump();
      expect(cong.value, isTrue);
      c.read(caiDatProvider.notifier).datDongY(trucTuyen: false);
      await tester.pump();
      expect(cong.value, isFalse);
    });

    testWidgets('người dùng cũ chưa trả lời thông báo: hiện lại giới thiệu, '
        'đồng ý -> mở cổng', (tester) async {
      datManHinh(tester, manHinh12[3]);
      datHeThong(tester, oChup.first);
      final cong = CongTrucTuyen(mo: false);
      await tester.pumpWidget(
        appThu(
          daXem: false,
          them: [
            caiDatProvider.overrideWith(_CaiDatCu.new),
            congTrucTuyenProvider.overrideWithValue(cong),
          ],
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(ManGioiThieu), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bat-dau')));
      await tester.pumpAndSettle();
      expect(find.byType(ManGioiThieu), findsNothing);
      expect(cong.value, isTrue);
    });
  });
}

/// Cài đặt của bản trước A8a: đã qua giới thiệu, chưa có `dongY`.
class _CaiDatCu extends CaiDatNotifier {
  @override
  CaiDat build() => const CaiDat(daXemGioiThieu: true);
}
