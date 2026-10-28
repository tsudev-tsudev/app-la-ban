import 'dart:io';
import 'dart:math' as math;

import 'package:compass_feature/compass_feature.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';
import 'package:storage/storage.dart';

TuTruongDiaCau tuTruong(double doLech, {bool ngoaiHan = false}) {
  final r = doSangRad(doLech);
  return TuTruongDiaCau(
    x: 40000 * math.cos(r),
    y: 40000 * math.sin(r),
    z: 20000,
    ngoaiHan: ngoaiHan,
  );
}

HuongDoc doc({
  double phuongVi = 0,
  double docGoc = 0,
  double lan = 0,
  MucTinCay muc = MucTinCay.thap,
  int tNs = 0,
}) => HuongDoc(
  phuongVi: phuongVi,
  phuongViTho: phuongVi,
  doc: docGoc,
  lan: lan,
  theoCamera: false,
  muc: muc,
  nhieuTu: false,
  canHieuChuan: muc == MucTinCay.thap,
  cuongDoTu: 45,
  nguon: NguonHuong.madgwick,
  dungYen: false,
  tNs: tNs,
);

void main() {
  group('tinhHuongHienThi', () {
    test('bắc từ: giữ nguyên, vẫn báo độ lệch nếu có vị trí', () {
      final h = tinhHuongHienThi(
        100,
        muonBacThuc: false,
        tuTruong: tuTruong(-1),
      );
      expect(h.phuongVi, 100);
      expect(h.bacThuc, isFalse);
      expect(h.thieuViTri, isFalse);
      expect(h.doLech, closeTo(-1, 1e-3));
    });

    test('bắc thực = bắc từ + độ lệch, chuẩn hoá qua 0°', () {
      final h = tinhHuongHienThi(
        359.5,
        muonBacThuc: true,
        tuTruong: tuTruong(2),
      );
      expect(h.bacThuc, isTrue);
      expect(h.phuongVi, closeTo(1.5, 1e-3));
      final tay = tinhHuongHienThi(
        0.5,
        muonBacThuc: true,
        tuTruong: tuTruong(-1),
      );
      expect(tay.phuongVi, closeTo(359.5, 1e-3));
    });

    test('muốn bắc thực nhưng chưa có vị trí -> bắc từ + cờ thiếu vị trí', () {
      final h = tinhHuongHienThi(42, muonBacThuc: true);
      expect(h.phuongVi, 42);
      expect(h.bacThuc, isFalse);
      expect(h.thieuViTri, isTrue);
      expect(h.doLech, isNull);
    });

    test('mô hình hết hạn -> cờ moHinhCu', () {
      final h = tinhHuongHienThi(
        42,
        muonBacThuc: true,
        tuTruong: tuTruong(0, ngoaiHan: true),
      );
      expect(h.moHinhCu, isTrue);
    });

    test('soDo01: 0,1°, 359,96 -> 0,0', () {
      expect(
        const HuongHienThi(
          phuongVi: 127.44,
          bacThuc: false,
          thieuViTri: false,
        ).soDo01,
        127.4,
      );
      expect(
        const HuongHienThi(
          phuongVi: 359.96,
          bacThuc: false,
          thieuViTri: false,
        ).soDo01,
        0,
      );
    });
  });

  group('BoRungMoc', () {
    test('mẫu đầu không rung; qua mốc Đông (90°) thì rung một lần', () {
      final b = BoRungMoc();
      expect(b.nap(60), isNull);
      expect(b.nap(66), isNull); // còn trong cung Đông Bắc
      expect(b.nap(69), isNull); // qua ranh 67,5 nhưng chưa vượt trễ
      expect(b.nap(71), 2);
      expect(b.nap(80), isNull);
    });

    test('kim run quanh ranh giới không rung lặp', () {
      final b = BoRungMoc()..nap(60);
      var soLan = 0;
      for (var i = 0; i < 50; i++) {
        if (b.nap(i.isEven ? 66.5 : 69.5) != null) soLan++;
      }
      expect(soLan, 0);
    });

    test('xoay ngược qua 0° (10° -> 310°) rung mốc Tây Bắc', () {
      final b = BoRungMoc()..nap(10);
      expect(b.nap(340), isNull); // vẫn cung Bắc
      expect(b.nap(310), 7);
      expect(b.nap(10), 0);
    });

    test('datLai: mẫu kế tiếp chỉ ghi nhận', () {
      final b = BoRungMoc()
        ..nap(0)
        ..datLai();
      expect(b.nap(180), isNull);
    });
  });

  group('TienDoHieuChuan', () {
    test('quét đủ 8 cung + 4 tư thế -> xong', () {
      final t = TienDoHieuChuan();
      expect(t.tiLe, 0);
      for (var i = 0; i < 8; i++) {
        t.nap(doc(phuongVi: i * 45.0));
      }
      expect(t.daPhu, 8);
      expect(t.xong, isFalse);
      t
        ..nap(doc(docGoc: 30))
        ..nap(doc(docGoc: -30))
        ..nap(doc(lan: 30));
      expect(t.xong, isFalse);
      t.nap(doc(lan: -30));
      expect(t.tiLe, 1);
      expect(t.xong, isTrue);
    });

    test('tin cậy cao ổn định 1,5 s + đã phủ nửa -> xong sớm', () {
      final t = TienDoHieuChuan();
      for (var i = 0; i < 6; i++) {
        t.nap(doc(phuongVi: i * 45.0));
      }
      t.nap(doc(muc: MucTinCay.cao));
      expect(t.xong, isFalse);
      t.nap(doc(muc: MucTinCay.cao, tNs: 1600000000));
      expect(t.xong, isTrue);
    });

    test('tin cậy cao bị ngắt quãng thì đếm lại', () {
      final t = TienDoHieuChuan();
      for (var i = 0; i < 6; i++) {
        t.nap(doc(phuongVi: i * 45.0));
      }
      t
        ..nap(doc(muc: MucTinCay.cao))
        ..nap(doc(tNs: 1000000000))
        ..nap(doc(muc: MucTinCay.cao, tNs: 1200000000))
        ..nap(doc(muc: MucTinCay.cao, tNs: 2000000000));
      expect(t.xong, isFalse);
    });

    test('tin cậy cao nhưng phủ chưa tới nửa -> chưa xong', () {
      final t = TienDoHieuChuan()
        ..nap(doc(muc: MucTinCay.cao))
        ..nap(doc(muc: MucTinCay.cao, tNs: 3000000000));
      expect(t.xong, isFalse);
    });
  });

  group('TuyChonLaBan', () {
    test('mặc định bật cả hai, JSON khứ hồi', () {
      const t = TuyChonLaBan();
      expect(t.bacThuc, isTrue);
      expect(t.rung, isTrue);
      final t2 = t.copyWith(rung: false);
      expect(TuyChonLaBan.tuJson(t2.toJson()), t2);
      expect(t2.hashCode, TuyChonLaBan.tuJson(t2.toJson()).hashCode);
    });

    test('tệp hỏng / thiếu khoá -> mặc định', () {
      expect(TuyChonLaBan.tuJson(const {}), const TuyChonLaBan());
      expect(
        TuyChonLaBan.tuJson(const {'bacThuc': 'x', 'rung': 3}),
        const TuyChonLaBan(),
      );
    });
  });

  test('ViTriDiaLy so sánh theo giá trị', () {
    const a = ViTriDiaLy(viDo: 21, kinhDo: 105);
    expect(a, const ViTriDiaLy(viDo: 21, kinhDo: 105));
    expect(a.hashCode, const ViTriDiaLy(viDo: 21, kinhDo: 105).hashCode);
    expect(a == const ViTriDiaLy(viDo: 21, kinhDo: 106), isFalse);
  });

  test(
    'viTriProvider: đặt vị trí -> tuTruongProvider tính WMM, xoá -> null',
    () {
      final c = ProviderContainer(
        overrides: [
          dongHoProvider.overrideWithValue(() => DateTime.utc(2026, 6)),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(tuTruongProvider), isNull);
      c.read(viTriProvider.notifier).viTri = const ViTriDiaLy(
        viDo: 10.78,
        kinhDo: 106.7,
      );
      expect(c.read(viTriProvider.notifier).viTri?.viDo, 10.78);
      expect(c.read(tuTruongProvider)?.doLech, inInclusiveRange(-2.0, 0.5));
      c.read(viTriProvider.notifier).viTri = null;
      expect(c.read(tuTruongProvider), isNull);
    },
  );

  test('KhoTuyChonLaBanTep đọc / ghi tệp JSON', () async {
    final tm = Directory.systemTemp.createTempSync('la_ban_');
    addTearDown(() => tm.deleteSync(recursive: true));
    final kho = KhoTuyChonLaBanTep(TepJson.mo('${tm.path}/la_ban.json'));
    expect(kho.doc(), const TuyChonLaBan());
    await kho.ghi(const TuyChonLaBan(rung: false));
    expect(
      KhoTuyChonLaBanTep(TepJson.mo('${tm.path}/la_ban.json')).doc(),
      const TuyChonLaBan(rung: false),
    );
  });
}
