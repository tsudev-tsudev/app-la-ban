import 'package:app_shell/src/flavor.dart';
import 'package:app_shell/src/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dichChuyenHuong', () {
    String? d({required bool daXem, required String viTri}) =>
        dichChuyenHuong(daXemGioiThieu: daXem, viTri: viTri, tabDau: '/la-ban');

    test('chưa xem giới thiệu: mọi đường dẫn về /chao', () {
      expect(d(daXem: false, viTri: '/la-ban'), duongDanGioiThieu);
      expect(d(daXem: false, viTri: '/cai-dat'), duongDanGioiThieu);
      expect(d(daXem: false, viTri: duongDanGioiThieu), isNull);
    });

    test('link chia sẻ điểm mở được cả khi chưa xem giới thiệu', () {
      expect(d(daXem: false, viTri: '/w/AQ'), isNull);
      expect(d(daXem: true, viTri: '/w/AQ'), isNull);
    });

    test('đã xem: rời /chao về tab đầu, các đường khác giữ nguyên', () {
      expect(d(daXem: true, viTri: duongDanGioiThieu), '/la-ban');
      expect(d(daXem: true, viTri: '/diem'), isNull);
    });
  });

  test('gói + tên launcher theo sản phẩm x flavor (M2)', () {
    CauHinhSanPham c(Flavor f, LoaiApp s) =>
        CauHinhSanPham(flavor: f, loai: s, phienBan: '0.0.0+1');
    expect(c(Flavor.dev, LoaiApp.mienPhi).appName, 'La bàn DEV');
    expect(c(Flavor.staging, LoaiApp.mienPhi).appName, 'La bàn STG');
    expect(c(Flavor.prod, LoaiApp.mienPhi).appName, 'La bàn');
    expect(c(Flavor.prod, LoaiApp.mienPhi).goi, 'com.tsudev.laban');
    expect(c(Flavor.dev, LoaiApp.mienPhi).goi, 'com.tsudev.laban.dev');
    expect(c(Flavor.prod, LoaiApp.pro).goi, 'com.tsudev.laban.pro');
    expect(c(Flavor.staging, LoaiApp.pro).goi, 'com.tsudev.laban.pro.stg');
    expect(c(Flavor.dev, LoaiApp.pro).appName, 'La bàn Pro DEV');
    expect(c(Flavor.prod, LoaiApp.pro).appName, 'La bàn Pro');
    expect(c(Flavor.prod, LoaiApp.pro).laPro, isTrue);
  });
}
