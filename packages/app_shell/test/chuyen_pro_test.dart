import 'dart:convert';
import 'dart:typed_data';

import 'package:app_shell/src/chuyen_pro.dart';
import 'package:app_shell/src/domain/chuyen_pro.dart';
import 'package:app_shell/src/flavor.dart';
import 'package:app_shell/src/pro.dart';
import 'package:compass_feature/compass_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

import 'ho_tro.dart';

const _gio = 1793437200000;

DiemMoc _d(String id, {String ten = 'Điểm', int sua = _gio}) => DiemMoc(
  id: id,
  ten: ten,
  viDo: 21.0285,
  kinhDo: 105.8522,
  caoDo: 12,
  ghiChu: 'ghi chú',
  taoLuc: _gio - 1000,
  suaLuc: sua,
);

final _jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 0xff, 0xd9]);

Uint8List _goi({
  List<DiemMoc>? diem,
  List<AnhChuyen>? anh,
  List<VungChuyen>? vung,
  Map<String, Object?> caiDat = const {'ngonNgu': 'en', 'cheDo': 'toi'},
}) => utf8.encode(
  jsonEncode(
    taoGoiChuyen(
      phienBanApp: '0.1.0-beta.18+18',
      luc: DateTime.utc(2026, 11, 5),
      diem: diem ?? [_d('a', ten: 'Hồ Gươm'), _d('b')],
      anh: anh ?? [(diemId: 'a', duLieu: _jpeg, rong: 4, cao: 3, taoLuc: _gio)],
      vung:
          vung ??
          [
            (
              ten: 'Hà Nội',
              bac: 21.1,
              nam: 20.9,
              dong: 105.95,
              tay: 105.7,
              zMin: 9,
              zMax: 14,
              tongQuan: false,
            ),
          ],
      caiDat: {...caiDat, 'daXemGioiThieu': true, 'baoLoi': true},
      tuyChonLaBan: const {'bacThuc': false, 'rung': true},
      viTri: const {'dinhDang': 'utm', 'viDo': 21.0, 'kinhDo': 105.8},
    ),
  ),
);

final class _NenTangGia implements NenTangChuyenPro {
  new({this.kia = true, this.yeuCau});

  final bool kia;
  YeuCauChuyen? yeuCau;
  Uint8List? daGui;
  int daMo = 0;

  @override
  Future<bool> ungDungKiaHopLe() async => kia;

  @override
  Future<bool> guiSangPro(Uint8List goi) async {
    daGui = goi;
    return true;
  }

  @override
  Future<bool> moUngDungKia() async {
    daMo++;
    return kia;
  }

  @override
  Future<YeuCauChuyen?> layYeuCau() async {
    final y = yeuCau;
    yeuCau = null;
    return y;
  }
}

const _cauHinhPro = CauHinhSanPham(
  flavor: Flavor.dev,
  loai: LoaiApp.pro,
  phienBan: '0.1.0-beta.2+2',
);

/// Bơm khung + cho isolate (Isolate.run đọc / đóng gói) chạy bằng thời gian
/// thật.
Future<void> _cho(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('docGoiChuyen', () {
    test('khứ hồi đủ điểm, ảnh, vùng, cài đặt; KHÔNG mang đồng ý / vị trí', () {
      final byte = _goi();
      final g = docGoiChuyen(byte);
      expect(g.diem, [_d('a', ten: 'Hồ Gươm'), _d('b')]);
      expect(g.anh.single.duLieu, _jpeg);
      expect(g.anh.single.diemId, 'a');
      expect(g.vung.single.ten, 'Hà Nội');
      expect(g.vung.single.zMax, 14);
      expect(g.caiDat, (
        ngonNgu: 'en',
        cheDo: 'toi',
        bacThuc: false,
        rung: true,
        dinhDangToaDo: 'utm',
      ));
      expect(g.boQua, 0);
      expect(g.coAnhVung, isTrue);
      final j = utf8.decode(byte);
      expect(j, isNot(contains('baoLoi')));
      expect(j, isNot(contains('daXemGioiThieu')));
      expect(j, isNot(contains('105.8,')));
    });

    test('nhận tệp "Xuất dữ liệu cá nhân" (mốc ISO) - không ảnh / vùng', () {
      final j = goiDuLieuXuat(
        phienBanApp: '0.1.0',
        luc: DateTime.utc(2026, 11, 5),
        caiDat: const {'ngonNgu': 'vi'},
        tuyChonLaBan: const {},
        viTri: const {},
        diem: [
          {
            'id': 'x',
            'ten': 'Đỉnh',
            'viDo': 22.3,
            'kinhDo': 103.77,
            'caoDo': null,
            'ghiChu': '',
            'taoLuc': '2026-10-31T09:00:00.000Z',
            'suaLuc': '2026-10-31T10:00:00.000Z',
          },
        ],
      );
      final g = docGoiChuyen(utf8.encode(jsonEncode(j)));
      expect(g.coAnhVung, isFalse);
      expect(g.diem.single.taoLuc, _gio);
      expect(g.diem.single.suaLuc, _gio + 3600000);
      expect(g.caiDat.ngonNgu, 'vi');
    });

    test('sai định dạng / phiên bản mới hơn / không phải JSON -> lỗi', () {
      Uint8List b(Object o) => utf8.encode(jsonEncode(o));
      expect(
        () => docGoiChuyen(b({'dinhDang': 'gpx', 'phienBanDinhDang': 1})),
        throwsFormatException,
      );
      expect(
        () => docGoiChuyen(
          b({'dinhDang': dinhDangChuyenPro, 'phienBanDinhDang': 99}),
        ),
        throwsFormatException,
      );
      expect(
        () => docGoiChuyen(Uint8List.fromList([0x7b, 0xff])),
        throwsFormatException,
      );
      expect(() => docGoiChuyen(b([1, 2])), throwsFormatException);
    });

    test(
      'mục sai bị bỏ và đếm: toạ độ hỏng, id trùng, ảnh mồ côi, vùng lạ',
      () {
        final j = jsonDecode(
          utf8.decode(_goi(diem: [_d('a'), _d('a')])),
        ) as Map<String, Object?>;
        (j['diem']! as List).add({'id': 'z', 'ten': 'x', 'viDo': 91});
        (j['anh']! as List).add({
          'diemId': 'khong-co',
          'rong': 1,
          'cao': 1,
          'taoLuc': 1,
          'duLieu': base64.encode(_jpeg),
        });
        (j['vung']! as List).add({'ten': 'v', 'bac': 1, 'nam': 2});
        j['caiDat'] = {'ngonNgu': 'fr', 'cheDo': 'toi'};
        final g = docGoiChuyen(utf8.encode(jsonEncode(j)));
        expect(g.diem.map((d) => d.id), ['a']);
        expect(g.anh, hasLength(1));
        expect(g.vung, hasLength(1));
        expect(g.boQua, 4);
        expect(g.caiDat.ngonNgu, isNull);
      },
    );

    test('quá 6 ảnh một điểm -> phần thừa bị bỏ', () {
      final g = docGoiChuyen(
        _goi(
          anh: [
            for (var i = 0; i < 8; i++)
              (diemId: 'a', duLieu: _jpeg, rong: 4, cao: 3, taoLuc: i),
          ],
        ),
      );
      expect(g.anh, hasLength(anhChuyenToiDa));
      expect(g.boQua, 2);
    });
  });

  group('keHoachNhapPro', () {
    test(
      'mới -> thêm kèm ảnh; sửa sau -> cập nhật (không nhân ảnh); cũ -> giữ',
      () {
        final g = docGoiChuyen(
          _goi(
            diem: [
              _d('a', ten: 'Mới'),
              _d('b', sua: _gio + 5),
              _d('c'),
            ],
            anh: [
              (diemId: 'a', duLieu: _jpeg, rong: 4, cao: 3, taoLuc: 1),
              (diemId: 'b', duLieu: _jpeg, rong: 4, cao: 3, taoLuc: 1),
            ],
          ),
        );
        final kh = keHoachNhapPro(g, coSan: {'b': _d('b'), 'c': _d('c')});
        expect(kh.them.map((d) => d.id), ['a']);
        expect(kh.capNhat.map((d) => d.id), ['b']);
        expect(kh.trung, 1);
        expect(kh.anh.map((a) => a.diemId), ['a']);
      },
    );

    test('nhập lại cùng gói -> không đổi gì', () {
      final g = docGoiChuyen(_goi());
      final kh = keHoachNhapPro(g, coSan: {for (final d in g.diem) d.id: d});
      expect(kh.them, isEmpty);
      expect(kh.capNhat, isEmpty);
      expect(kh.anh, isEmpty);
      expect(kh.trung, 2);
    });
  });

  group('màn chuyển (widget)', () {
    testWidgets('app Pro nhận gói -> xem lại -> nhập đủ điểm, ảnh, cài đặt', (
      tester,
    ) async {
      final kho = KhoDiemBoNho([_d('b')]);
      final nt = _NenTangGia(yeuCau: (moChuyen: false, goi: _goi()));
      await tester.pumpWidget(
        appThu(
          khoDiem: false,
          them: [
            khoDiemProvider.overrideWithValue(kho),
            cauHinhSanPhamProvider.overrideWithValue(_cauHinhPro),
            nenTangChuyenProProvider.overrideWithValue(nt),
          ],
        ),
      );
      await _cho(tester);
      expect(find.byType(ManNhapTuMienPhi), findsOneWidget);
      expect(find.byKey(const ValueKey('nhap-ke-hoach')), findsOneWidget);
      // Chưa bấm Nhập thì chưa ghi gì.
      expect(await kho.tatCa(), hasLength(1));

      await tester.tap(find.byKey(const ValueKey('nhap-xac-nhan')));
      await _cho(tester);
      final ds = await kho.tatCa();
      expect(ds.map((d) => d.id).toSet(), {'a', 'b'});
      expect(await kho.theoDoiAnh('a').first, hasLength(1));
      expect(await kho.theoDoiAnh('b').first, isEmpty);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(ManNhapTuMienPhi)),
      ).read(caiDatProvider);
      expect(c.ngonNgu, LuaChonNgonNgu.en);
      expect(c.cheDo, CheDoGiaoDien.toi);
      // Đồng ý xử lý dữ liệu của app Pro giữ nguyên.
      expect(c.dongY, dongYThu);
      expect(
        ProviderScope.containerOf(tester.element(find.byType(ManNhapTuMienPhi)))
            .read(tuyChonLaBanProvider)
            .bacThuc,
        isFalse,
      );
      expect(find.byKey(const ValueKey('nhap-xong')), findsOneWidget);
      // Vùng offline: chỉ hiện nút tải lại.
      expect(find.text('Hà Nội'), findsOneWidget);
    });

    testWidgets('app Pro mở từ Cài đặt: "Lấy từ La bàn" mở bản miễn phí', (
      tester,
    ) async {
      final nt = _NenTangGia();
      await tester.pumpWidget(
        appThu(
          them: [
            cauHinhSanPhamProvider.overrideWithValue(_cauHinhPro),
            nenTangChuyenProProvider.overrideWithValue(nt),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab/cai-dat')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('muc-nhap-mien-phi')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ManCaiDat),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('muc-nhap-mien-phi')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('muc-nhap-mien-phi')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nhap-tu-mien-phi')));
      await tester.pumpAndSettle();
      expect(nt.daMo, 1);
    });

    testWidgets('bản miễn phí: ẩn mục khi không có Pro hợp lệ', (tester) async {
      await tester.pumpWidget(
        appThu(
          them: [
            nenTangChuyenProProvider.overrideWithValue(_NenTangGia(kia: false)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab/cai-dat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('muc-chuyen-pro')), findsNothing);
    });

    testWidgets('bản miễn phí: Pro mở màn chuyển -> gửi gói đọc lại được', (
      tester,
    ) async {
      final kho = KhoDiemBoNho([_d('a'), _d('b')]);
      await kho.themAnh('a', (duLieu: _jpeg, rong: 4, cao: 3), luc: 1);
      final nt = _NenTangGia(yeuCau: (moChuyen: true, goi: null));
      await tester.pumpWidget(
        appThu(
          khoDiem: false,
          them: [
            khoDiemProvider.overrideWithValue(kho),
            nenTangChuyenProProvider.overrideWithValue(nt),
          ],
        ),
      );
      await _cho(tester);
      expect(find.byType(ManChuyenSangPro), findsOneWidget);
      expect(find.byKey(const ValueKey('chuyen-dem')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chuyen-gui')));
      await _cho(tester);
      final g = docGoiChuyen(nt.daGui!);
      expect(g.diem.map((d) => d.id).toSet(), {'a', 'b'});
      expect(g.anh.single.duLieu, _jpeg);
    });
  });
}
