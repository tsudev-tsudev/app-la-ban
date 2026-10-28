import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

import '../mo_phong.dart';

List<HuongDoc> chay(BoHopNhat bo, Iterable<MauCamBien> ds) => [
  for (final m in ds) ?bo.nap(m),
];

void main() {
  test('đủ cảm biến -> Madgwick, đúng hướng, tin cậy cao', () {
    final ra = chay(BoHopNhat(), moPhong((_) => tuGoc(72, 10, -5)));
    expect(ra, isNotEmpty);
    final c = ra.last;
    expect(c.nguon, NguonHuong.madgwick);
    expect(saiSo(c.phuongVi, 72), lessThan(1));
    expect(c.muc, MucTinCay.cao);
    expect(c.nhieuTu, isFalse);
    expect(c.cuongDoTu, closeTo(44.8, 1.5));
    expect(c.doc, closeTo(10, 1));
    expect(c.theoCamera, isFalse);
    expect(c.apSuat, isNull);
  });

  test('ưu tiên hệ thống / không con quay -> vectơ quay OS', () {
    final ds = moPhong((_) => tuGoc(200, 0, 0), thoiGian: 1);
    final a = chay(BoHopNhat(uuTienHeThong: true), ds).last;
    expect(a.nguon, NguonHuong.heThong);
    expect(saiSo(a.phuongVi, 200), lessThan(0.5));
    final b = chay(
      BoHopNhat(),
      moPhong((_) => tuGoc(200, 0, 0), thoiGian: 1, coConQuay: false),
    ).last;
    expect(b.nguon, NguonHuong.heThong);
  });

  test(
    'máy rẻ không con quay, không vectơ quay -> bù nghiêng gia tốc + từ',
    () {
      final ra = chay(
        BoHopNhat(),
        moPhong(
          (_) => tuGoc(315, -20, 10),
          thoiGian: 2,
          coConQuay: false,
          coXoayVector: false,
        ),
      );
      expect(ra.last.nguon, NguonHuong.giaTocTu);
      expect(saiSo(ra.last.phuongVi, 315), lessThan(1.5));
    },
  );

  test('xoay liên tục qua 0°: đầu ra không bao giờ nhảy > 5° giữa hai lần', () {
    final ra = chay(
      BoHopNhat(),
      moPhong((t) => tuGoc(330 + 30 * t, 5, 0), thoiGian: 4),
    );
    for (var i = 1; i < ra.length; i++) {
      expect(saiSo(ra[i].phuongVi, ra[i - 1].phuongVi), lessThan(5));
    }
    expect(saiSo(ra.last.phuongVi, 330 + 30 * 3.99), lessThan(3));
  });

  test('màn hình xoay ngang cộng 90°', () {
    final bo = BoHopNhat()..nap(const MauCamBien(LoaiMau.xoayManHinh, 0, x: 1));
    final c = chay(bo, moPhong((_) => tuGoc(10, 0, 0))).last;
    expect(saiSo(c.phuongVi, 100), lessThan(1));
  });

  test('gần nam châm: báo nhiễu, hướng giữ nhờ con quay', () {
    final ds = moPhong(
      (_) => tuGoc(150, 0, 0),
      thoiGian: 6,
      // Từ 3 s: cộng nhiễu lớn hướng Đông.
      tuTruong: (t) => t < 3 ? tuHaNoi : tuHaNoi + const Vec3(60, 0, 0),
    );
    final ra = chay(BoHopNhat(), ds);
    final c = ra.last;
    expect(c.nhieuTu, isTrue);
    expect(c.muc, MucTinCay.thap);
    expect(saiSo(c.phuongVi, 150), lessThan(2));
  });

  test('độ chính xác OS thấp -> cần hiệu chuẩn', () {
    final c = chay(
      BoHopNhat(),
      moPhong((_) => tuGoc(0, 0, 0), thoiGian: 1, doChinhXacTu: 1),
    ).last;
    expect(c.muc, MucTinCay.thap);
    expect(c.canHieuChuan, isTrue);
  });

  test('đứng yên > 3 s thì báo dungYen; khí áp đi kèm', () {
    final bo = BoHopNhat()
      ..nap(const MauCamBien(LoaiMau.apSuat, 0, x: 1000.5))
      ..nap(const MauCamBien(LoaiMau.xoayGame, 0));
    final ra = chay(bo, moPhong((_) => tuGoc(60, 0, 0), thoiGian: 4));
    expect(ra.first.dungYen, isFalse);
    expect(ra.last.dungYen, isTrue);
    expect(ra.last.apSuat, 1000.5);
  });

  test(
    'tạm dừng rồi tiếp tục (khoảng trống > 0,5 s) -> khởi tạo lại tức thì',
    () {
      final bo = BoHopNhat();
      chay(bo, moPhong((_) => tuGoc(20, 0, 0), thoiGian: 2));
      final sau = chay(
        bo,
        moPhong(
          (_) => tuGoc(250, 0, 0),
          thoiGian: 0.05,
          tBatDauNs: 60e9.toInt(),
        ),
      );
      expect(saiSo(sau.first.phuongVi, 250), lessThan(1));
    },
  );

  test('chưa có gia tốc / từ thì chưa xuất', () {
    final bo = BoHopNhat();
    expect(bo.nap(const MauCamBien(LoaiMau.conQuay, 0)), isNull);
    expect(bo.nap(const MauCamBien(LoaiMau.tu, 0, y: 40)), isNull);
  });
}
