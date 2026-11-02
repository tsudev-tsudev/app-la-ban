import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_feature/location_feature.dart';

import 'ho_tro.dart';

void main() {
  test('vị trí giả: báo MỘT lần mỗi lượt nghe, vẫn phát vị trí', () async {
    DocViTri doc({required bool gia}) => DocViTri(
      viDo: 21,
      kinhDo: 105.8,
      luc: DateTime.utc(2026, 11, 2),
      gia: gia,
    );
    final daBao = <DocViTri>[];
    final c = ProviderContainer(
      overrides: [
        nguonViTriProvider.overrideWithValue(
          NguonViTriGhiSan([doc(gia: false), doc(gia: true), doc(gia: true)]),
        ),
        baoViTriGiaProvider.overrideWithValue(daBao.add),
      ],
    );
    addTearDown(c.dispose);
    final nhan = <DocViTri>[];
    c.listen(docViTriProvider, (_, v) {
      if (v.value case final d?) nhan.add(d);
    }, fireImmediately: true);
    await c.read(quyenViTriProvider.future);
    await pumpEventQueue();
    // Riverpod gộp giá trị phát dồn - chỉ cần vị trí vẫn tới màn.
    expect(nhan, isNotEmpty);
    expect(daBao, hasLength(1));
    expect(daBao.single.gia, isTrue);
  });

  group('geoid EGM96 1°', () {
    final g = LuoiGeoid.tuBytes(
      ByteData.sublistView(
        File('assets/geoid_egm96_1do.bin').readAsBytesSync(),
      ),
    );
    test("so lưới 15' của PROJ", () {
      final ds = mau('geoid');
      var lonNhat = 0.0;
      var tong = 0.0;
      for (final m in ds) {
        final d = (g.doCao(so(m['viDo']), so(m['kinhDo'])) - so(m['n'])).abs();
        tong += d;
        if (d > lonNhat) lonNhat = d;
        if (m['vn'] == true) expect(d, lessThan(1.5), reason: '$m');
      }
      expect(tong / ds.length, lessThan(1.0));
      expect(lonNhat, lessThan(12));
    });
    test('độ cao mực biển = elipxoit - N', () {
      expect(g.doCaoMucBien(21.0285, 105.8048, 0), closeTo(28.1, 1.5));
      expect(g.doCao(0, 179.9), closeTo(g.doCao(0, -180.1), 0.5));
    });
    test('sai định dạng', () {
      expect(() => LuoiGeoid.tuBytes(ByteData(10)), throwsFormatException);
    });
  });

  group('khí áp', () {
    test('ISA: 1013,25 hPa = 0 m, 899 hPa ~ 1000 m', () {
      expect(doCaoKhiAp(apSuatChuan), closeTo(0, 1e-9));
      expect(doCaoKhiAp(898.76), closeTo(1000, 2));
      expect(apSuatMucBienTu(898.76, 1000), closeTo(apSuatChuan, 0.3));
    });
    test('hiệu chỉnh QNH theo GPS, bỏ mẫu kém', () {
      final b = BoHieuChinhKhiAp();
      expect(b.daHieuChinh, isFalse);
      b
        ..nap(1000, 50, 40)
        ..nap(null, 50, 3)
        ..nap(1000, 50, null)
        ..nap(500, 0, 3);
      expect(b.daHieuChinh, isFalse);
      // QNH thật 1020 hPa: máy ở 100 m đo được p.
      final pThat = 1020 / apSuatMucBienTu(1, 100);
      for (var i = 0; i < 30; i++) {
        b.nap(pThat, 100 + (i.isEven ? 4 : -4), 5);
      }
      expect(b.apSuatMucBien, closeTo(1020, 0.5));
      expect(b.doCao(pThat), closeTo(100, 5));
    });
  });

  group('thước thuỷ', () {
    test('bọt về phía cao, kẹp trong vòng tròn', () {
      final t = tinhThuocThuy(5, 0);
      expect(t.y, closeTo(-0.5, 1e-9));
      expect(t.x, 0);
      final p = tinhThuocThuy(0, 20);
      expect(p.x, closeTo(1, 1e-9));
      final c = tinhThuocThuy(30, 30);
      expect(c.x * c.x + c.y * c.y, closeTo(1, 1e-9));
      expect(tinhThuocThuy(3, 4).nghieng, closeTo(5, 0.05));
    });
    test('cân bằng có trễ', () {
      expect(tinhThuocThuy(0.3, 0.2).canBang, isTrue);
      expect(tinhThuocThuy(0.6, 0.3).canBang, isFalse);
      expect(tinhThuocThuy(0.6, 0.3, canBangTruoc: true).canBang, isTrue);
      expect(tinhThuocThuy(1.2, 0, canBangTruoc: true).canBang, isFalse);
    });
  });

  test('từ trường: dải 25-65 µT và lệch mô hình', () {
    expect(danhGiaTuTruong(45).batThuong, isFalse);
    expect(danhGiaTuTruong(20).batThuong, isTrue);
    expect(danhGiaTuTruong(70).batThuong, isTrue);
    final d = danhGiaTuTruong(45, moHinhNt: 45000);
    expect(d.moHinh, 45);
    expect(d.lechPhanTram, closeTo(0, 1e-9));
    expect(danhGiaTuTruong(60, moHinhNt: 45000).batThuong, isTrue);
  });

  group('đọc vị trí', () {
    test('giải mã sự kiện nền tảng', () {
      final d = giaiMaDocViTri([
        21.0,
        105.8,
        10.0,
        5.0,
        double.nan,
        1.5,
        90.0,
        1.7e12,
        double.nan,
        0,
      ])!;
      expect(d.viDo, 21);
      expect(d.doCaoElip, 10);
      expect(d.doChinhXacDung, isNull);
      expect(d.doCaoMucBien, isNull);
      expect(d.nguon, NguonDocViTri.gps);
      expect(d.gia, isFalse);
      expect(d.luc.isUtc, isTrue);
      expect(
        d,
        giaiMaDocViTri([
          21.0,
          105.8,
          10.0,
          5.0,
          double.nan,
          1.5,
          90.0,
          1.7e12,
          double.nan,
          0,
        ]),
      );
      expect(
        giaiMaDocViTri([21.0, 105.8, 0, 0, 0, 0, 0, 1.7e12, 0, 0, 1])!.gia,
        isTrue,
      );
      expect(
        giaiMaDocViTri([21.0, 105.8, 0, 0, 0, 0, 0, 1.7e12, 0, 0, 0])!.gia,
        isFalse,
      );
      expect(giaiMaDocViTri([1, 2]), isNull);
      expect(giaiMaDocViTri('x'), isNull);
      expect(giaiMaDocViTri([95, 0, 0, 0, 0, 0, 0, 1, 0, 9]), isNull);
      expect(
        giaiMaDocViTri([1, 2, 0, 0, 0, 0, 0, 1, 0, 9])!.nguon,
        NguonDocViTri.khac,
      );
    });
    test('quyền', () {
      expect(quyenTuChuoi('xapXi'), QuyenViTri.xapXi);
      expect(quyenTuChuoi('lạ'), QuyenViTri.chuaHoi);
      expect(QuyenViTri.chinhXac.duocPhep, isTrue);
      expect(QuyenViTri.tuChoiHan.duocPhep, isFalse);
    });
    test('làm tròn lưu + ngưỡng dời chỗ', () {
      expect(lamTronLuu(21.0285, 105.8548), (viDo: 21.0, kinhDo: 105.9));
      expect(daDoiCho(null, 0, 0), isTrue);
      const cu = (viDo: 21.0, kinhDo: 105.0);
      expect(daDoiCho(cu, 21.0003, 105), isFalse);
      expect(daDoiCho(cu, 21.001, 105), isTrue);
    });
  });

  test('đăng ký giấy phép dữ liệu ODbL + EGM96', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dangKyGiayPhepDuLieu(bundle: _BoDocTep());
    final ds = await LicenseRegistry.licenses.toList();
    final muc = ds.where((l) => l.packages.contains('OpenStreetMap (ODbL)'));
    expect(muc, hasLength(1));
    final vb = muc.single.paragraphs.map((p) => p.text).join('\n');
    expect(vb, contains('© OpenStreetMap contributors'));
    expect(vb, contains('EGM96'));
  });
}

class _BoDocTep extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    File(key.replaceFirst('packages/location_feature/', '')).readAsBytesSync(),
  );
}
