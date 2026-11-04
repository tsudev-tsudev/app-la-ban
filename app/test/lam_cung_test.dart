import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/cong_truc_tuyen.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/kenh.dart';
import 'package:la_ban/src/lam_cung.dart';
import 'package:la_ban/src/luu_tru.dart';
import 'package:location_feature/location_feature.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';
import 'package:test_kit/test_kit.dart';

import 'ho_tro.dart';

const _ref = 'REF-7K2QM-X9F3A';

TinhTrangThietBi tt(TrangThaiThietBi t, {MucTin muc = MucTin.device}) =>
    TinhTrangThietBi(
      trangThai: t,
      mucTin: muc,
      ref: t.index >= 2 ? _ref : null,
    );

final class _Kho implements KhoTrangThai {
  @override
  Map<String, Object?> duLieu = {};

  @override
  void ghiDongBo(Map<String, Object?> moi) => duLieu = moi;

  @override
  Future<void> ghi(Map<String, Object?> moi) async => duLieu = moi;
}

final class _NenTang implements NenTangThietBi {
  @override
  Future<KhoaThietBi> khoaCongKhai() async =>
      (spki: Uint8List(91), mucBaoMat: 'tee');

  @override
  Future<Uint8List> ky(Uint8List duLieu) async => Uint8List(70);

  @override
  Future<String?> integrity(int soDuAn, String requestHash) async => null;

  @override
  Future<ThongTinMay> thongTin() async =>
      (model: 'm', heDieuHanh: '13', goi: 'com.tsudev.laban.stg');

  @override
  Future<void> xoaKhoa() async {}

  @override
  Future<KetQuaNative> kiemTraMoiTruong() async =>
      const KetQuaNative(coNative: true, bitNative: KetQuaNative.bitFridaCong);

  @override
  Future<void> cheManHinh({required bool bat}) async {}
}

final class _Api implements ApiDinhDanh {
  @override
  Future<PhanHoiDinhDanh> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  }) async => (status: 503, duLieu: null);

  @override
  Future<PhanHoiKy> goiTho(
    String phuongThuc,
    String duongDan, {
    List<int>? than,
    Map<String, String> tieuDe = const {},
  }) async => (status: 503, duLieu: null, gioMayChu: null);
}

void main() {
  setUpAll(napFontThat);

  ({MucRuiRo muc, String? ref}) ruiRo({TinhTrangThietBi? t, String? daLuu}) {
    final c = ProviderContainer(
      overrides: [
        tinhTrangProvider.overrideWithValue(t),
        khoaDaLuuProvider.overrideWithValue(daLuu),
      ],
    );
    addTearDown(c.dispose);
    return c.read(ruiRoProvider);
  }

  test('chứng chỉ release: khoá upload (APK trực tiếp) + khoá Play (Q63)', () {
    expect(Flavor.chungChiHopLe, [Flavor.chungChiUpload, Flavor.chungChiPlay]);
    for (final h in Flavor.chungChiHopLe) {
      expect(h, matches(RegExp(r'^[0-9a-f]{64}$')));
    }
    final c = cauHinhFreeRasp(
      goi: Flavor.prod.goi,
      chungChi: Flavor.chungChiHopLe,
      banThat: true,
    );
    expect(c.androidConfig?.signingCertHashes, hasLength(2));
  });

  test('mức rủi ro theo trạng thái server; offline dùng khoá đã lưu', () {
    expect(ruiRo().muc, MucRuiRo.thap);
    expect(ruiRo(t: tt(TrangThaiThietBi.suspicious)).muc, MucRuiRo.trungBinh);
    expect(ruiRo(t: tt(TrangThaiThietBi.restricted)), (
      muc: MucRuiRo.cao,
      ref: _ref,
    ));
    expect(ruiRo(daLuu: _ref), (muc: MucRuiRo.nghiemTrong, ref: _ref));
    // Server đã gỡ cấm -> trạng thái mới thắng khoá đã lưu.
    expect(
      ruiRo(t: tt(TrangThaiThietBi.clean), daLuu: _ref).muc,
      MucRuiRo.thap,
    );
  });

  test('MEDIUM trở lên tắt chia sẻ / đồng bộ / quảng cáo, giữ bản đồ', () {
    final c = ProviderContainer(
      overrides: [
        tinhTrangProvider.overrideWithValue(tt(TrangThaiThietBi.suspicious)),
      ],
    );
    addTearDown(c.dispose);
    final co = c.read(coTinhNangProvider);
    expect(co[CoTinhNang.chiaSe], isFalse);
    expect(co[CoTinhNang.dongBo], isFalse);
    expect(co[CoTinhNang.banDo], isTrue);
    expect(coTatTheoRuiRo(MucRuiRo.thap), isEmpty);
  });

  test('trang khiếu nại theo ngôn ngữ', () {
    expect(
      trangKhieuNai(const Locale('vi')).toString(),
      'https://compass.tsudev.com/khieu-nai/',
    );
    expect(
      trangKhieuNai(const Locale('en'), ref: 'LB-7K2Q-9XWD').toString(),
      'https://compass.tsudev.com/en/appeal/?ref=LB-7K2Q-9XWD',
    );
    expect(trangKhieuNai(const Locale('vi'), ref: '').hasQuery, isFalse);
  });

  group('apKhoa', () {
    late _Kho tepRasp;
    late _Kho tepDinhDanh;
    late List<String> daGui;
    late DichVuRasp rasp;
    late DichVuDinhDanh dv;

    setUp(() {
      tepRasp = _Kho();
      tepDinhDanh = _Kho()
        ..duLieu = {
          'installationId': '0f8fad5b-d9cb-469f-a165-70867728950e',
          'phien': {'thietBiId': 'x'},
        };
      daGui = [];
      dv = DichVuDinhDanh(
        api: _Api(),
        nenTang: _NenTang(),
        tep: tepDinhDanh,
        cauHinh: CauHinhDinhDanh(
          soDuAnCloud: 1,
          phienBanApp: '0.1.0',
          build: 7,
          ngonNgu: () => 'vi',
        ),
      );
      rasp = DichVuRasp(
        nenTang: _NenTang(),
        tep: tepRasp,
        gui: (lo) async {
          daGui.addAll([for (final e in lo) e['type']! as String]);
          return Ok(lo.length);
        },
        cauHinh: const CauHinhRasp(
          phienBanApp: '0.1.0',
          build: 7,
          chungChiHopLe: [],
          guiMayChu: true,
        ),
        cho: Duration.zero,
      );
    });

    test('CRITICAL: gửi nốt sự kiện TRƯỚC, rồi huỷ phiên + lưu REF', () async {
      rasp.nhan((loai: LoaiTinHieu.hookFrida, chiTiet: {'port': true}));
      final huy = await apKhoa(rasp, dv, tt(TrangThaiThietBi.banned));
      expect(huy, isTrue);
      expect(daGui, ['HOOK_FRIDA']);
      expect(tepDinhDanh.duLieu.containsKey('phien'), isFalse);
      expect(tepDinhDanh.duLieu['installationId'], isNotNull);
      expect(tepRasp.duLieu['khoa'], _ref);
      // Lần thông báo sau không huỷ lại.
      expect(
        await apKhoa(rasp, dv, tt(TrangThaiThietBi.banned), daHuy: true),
        isFalse,
      );
    });

    test('gỡ cấm -> xoá khoá đã lưu, không đụng phiên', () async {
      tepRasp.duLieu = {'khoa': _ref};
      expect(await apKhoa(rasp, dv, tt(TrangThaiThietBi.clean)), isFalse);
      expect(tepRasp.duLieu.containsKey('khoa'), isFalse);
      expect(tepDinhDanh.duLieu.containsKey('phien'), isTrue);
    });

    test('vị trí giả -> MOCK_LOCATION chỉ khi đã đồng ý trực tuyến', () async {
      final d = DocViTri(
        viDo: 21,
        kinhDo: 105.8,
        luc: DateTime.utc(2026, 11, 2),
        nguon: NguonDocViTri.gps,
        gia: true,
      );
      baoViTriGia(rasp, CongTrucTuyen(mo: false))(d);
      expect(rasp.daThay, isEmpty);
      baoViTriGia(rasp, CongTrucTuyen(mo: true))(d);
      expect(rasp.daThay, {LoaiTinHieu.giaViTri});
      await rasp.xa();
      expect(daGui, ['MOCK_LOCATION']);
    });
  });

  Widget app(TinhTrangThietBi? t) =>
      appThu(them: [tinhTrangProvider.overrideWithValue(t)]);

  testWidgets('CRITICAL: chỉ còn màn khoá + REF, chép được mã', (tester) async {
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(app(tt(TrangThaiThietBi.banned)));
    await tester.pumpAndSettle();
    expect(find.byType(ManKhoa), findsOneWidget);
    expect(find.byKey(const ValueKey('tab/ban-do')), findsNothing);
    expect(find.textContaining(_ref), findsOneWidget);
    String? chep;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (c) async {
        if (c.method == 'Clipboard.setData') {
          chep = (c.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await tester.tap(find.byKey(const ValueKey('chep-ref')));
    await tester.pumpAndSettle();
    expect(chep, _ref);
    final mo = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('la_ban/thiet_bi'),
      (c) async {
        if (c.method == 'moTrang') {
          mo.add((c.arguments as Map)['url'] as String);
        }
        return c.method == 'moTrang' ? true : null;
      },
    );
    await tester.tap(find.byKey(const ValueKey('khieu-nai')));
    await tester.pumpAndSettle();
    expect(mo, ['https://compass.tsudev.com/khieu-nai/?ref=$_ref']);
  });

  testWidgets('HIGH: băng hạn chế + REF, la bàn vẫn dùng', (tester) async {
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(app(tt(TrangThaiThietBi.restricted)));
    await tester.pumpAndSettle();
    expect(find.byType(BangHanChe), findsOneWidget);
    expect(find.byKey(const ValueKey('tab/ban-do')), findsOneWidget);
    expect(find.byType(ManKhoa), findsNothing);
    expect(find.byKey(const ValueKey('khieu-nai-han-che')), findsOneWidget);
  });

  testWidgets('trợ năng: màn khoá + băng hạn chế', (tester) async {
    for (final t in [TrangThaiThietBi.banned, TrangThaiThietBi.restricted]) {
      await kiemTroNang(tester, (o) {
        datHeThong(tester, o);
        return app(tt(t));
      });
    }
  });

  testWidgets('LOW / MEDIUM: không hiện gì', (tester) async {
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(app(tt(TrangThaiThietBi.suspicious)));
    await tester.pumpAndSettle();
    expect(find.byType(BangHanChe), findsNothing);
    expect(find.byType(ManKhoa), findsNothing);
  });

  testWidgets('ma trận: màn khoá + băng hạn chế không tràn', (tester) async {
    await kiemMaTran(tester, (o) {
      datHeThong(tester, o);
      return app(tt(TrangThaiThietBi.banned));
    });
    await kiemMaTran(tester, (o) {
      datHeThong(tester, o);
      return app(tt(TrangThaiThietBi.restricted));
    });
  });

  testWidgets('golden: màn khoá / băng hạn chế', (tester) async {
    await chupGolden(tester, 'man_khoa', (o) {
      datHeThong(tester, o);
      return app(tt(TrangThaiThietBi.banned));
    });
    await chupGolden(tester, 'bang_han_che', (o) {
      datHeThong(tester, o);
      return app(tt(TrangThaiThietBi.restricted));
    });
  });
}
