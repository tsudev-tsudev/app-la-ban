import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/phien_ban.dart';
import 'package:la_ban/src/router.dart';

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

  test('phienBanApp khớp version trong pubspec.yaml', () {
    final dong = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(dong.substring('version:'.length).trim(), phienBanApp);
  });

  test('tên launcher theo flavor', () {
    expect(Flavor.dev.appName, 'La bàn DEV');
    expect(Flavor.staging.appName, 'La bàn STG');
    expect(Flavor.prod.appName, 'La bàn');
  });
}
