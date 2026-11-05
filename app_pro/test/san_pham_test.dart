import 'dart:io';

import 'package:app_shell/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban_pro/src/phien_ban.dart';
import 'package:la_ban_pro/src/san_pham.dart';

void main() {
  test('phienBanApp khớp version trong pubspec.yaml', () {
    final dong = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(dong.substring('version:'.length).trim(), phienBanApp);
  });

  test('app Pro: gói com.tsudev.laban.pro + hậu tố flavor', () {
    expect(cauHinhPro(Flavor.prod).laPro, isTrue);
    expect(cauHinhPro(Flavor.prod).goi, 'com.tsudev.laban.pro');
    expect(cauHinhPro(Flavor.staging).goi, 'com.tsudev.laban.pro.stg');
    expect(cauHinhPro(Flavor.dev).goi, 'com.tsudev.laban.pro.dev');
  });

  test('Gradle khớp gói Dart', () {
    final g = File('android/app/build.gradle.kts').readAsStringSync();
    expect(g, contains('applicationId = "${cauHinhPro(Flavor.prod).goi}"'));
    expect(g, contains('namespace = "com.tsudev.laban.pro"'));
  });

  test('không phụ thuộc gói / SDK quảng cáo (Q56)', () {
    final khoa = File('pubspec.yaml')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('#'))
        .map((l) => l.split(':').first.trim())
        .toSet();
    for (final cam in ['quang_cao', 'google_mobile_ads', 'ads_iap']) {
      expect(khoa, isNot(contains(cam)));
    }
  });
}
