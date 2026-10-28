import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

void main() {
  test('chuanHoaDo về [0, 360)', () {
    expect(chuanHoaDo(0), 0);
    expect(chuanHoaDo(360), 0);
    expect(chuanHoaDo(-0), 0);
    expect(chuanHoaDo(-1), 359);
    expect(chuanHoaDo(725), 5);
    expect(chuanHoaDo(-1e-15), lessThan(360));
  });

  test('hieuGoc lấy đường ngắn nhất qua 0°', () {
    expect(hieuGoc(1, 359), closeTo(2, 1e-9));
    expect(hieuGoc(359, 1), closeTo(-2, 1e-9));
    expect(hieuGoc(180, 0), 180);
    expect(hieuGoc(0, 180), 180);
    expect(hieuGoc(90, 90), 0);
    expect(hieuGoc(-170, 170), closeTo(20, 1e-9));
  });

  test('thongKeVong: 359° và 1° trung bình 0°, không phải 180°', () {
    final k = thongKeVong([359, 1, 358, 2]);
    expect(saiSoVong(k.trungBinh, 0), lessThan(1e-9));
    expect(k.r, closeTo(1, 0.001));
    expect(k.doLechChuan, closeTo(1.58, 0.05));
  });

  test('thongKeVong: tập rỗng / triệt tiêu', () {
    final rong = thongKeVong(const []);
    expect(rong.trungBinh, isNaN);
    expect(rong.doLechChuan, double.infinity);
    final doi = thongKeVong([0, 180]);
    expect(doi.trungBinh, isNaN);
    expect(doi.r, closeTo(0, 1e-9));
  });

  test('CuaSoVong trượt khớp thongKeVong của N mẫu cuối', () {
    final ds = <double>[350, 355, 0, 5, 10, 15, 20, 25];
    final cs = CuaSoVong(5);
    ds.forEach(cs.them);
    final cuoi = thongKeVong(ds.sublist(ds.length - 5));
    expect(cs.soMau, 5);
    expect(cs.thongKe.trungBinh, closeTo(cuoi.trungBinh, 1e-9));
    expect(cs.thongKe.r, closeTo(cuoi.r, 1e-9));
    cs.xoa();
    expect(cs.soMau, 0);
    expect(cs.thongKe.trungBinh, isNaN);
  });

  test('huongChinh 8 hướng, biên 22,5°', () {
    expect(huongChinh(0), HuongChinh.bac);
    expect(huongChinh(359), HuongChinh.bac);
    expect(huongChinh(22.4), HuongChinh.bac);
    expect(huongChinh(22.5), HuongChinh.dongBac);
    expect(huongChinh(90), HuongChinh.dong);
    expect(huongChinh(135), HuongChinh.dongNam);
    expect(huongChinh(180), HuongChinh.nam);
    expect(huongChinh(225), HuongChinh.tayNam);
    expect(huongChinh(270), HuongChinh.tay);
    expect(huongChinh(315), HuongChinh.tayBac);
    expect(huongChinh(-45), HuongChinh.tayBac);
  });

  test('đổi độ <-> radian', () {
    expect(radSangDo(doSangRad(123.4)), closeTo(123.4, 1e-9));
  });
}

double saiSoVong(double a, double b) => hieuGoc(a, b).abs();
