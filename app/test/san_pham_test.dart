import 'dart:io';

import 'package:app_shell/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/phien_ban.dart';
import 'package:la_ban/src/san_pham.dart';

void main() {
  test('phienBanApp khớp version trong pubspec.yaml', () {
    final dong = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(dong.substring('version:'.length).trim(), phienBanApp);
  });

  test('bản miễn phí: gói com.tsudev.laban, phiên bản của app này', () {
    final c = cauHinhMienPhi(Flavor.prod);
    expect(c.laPro, isFalse);
    expect(c.goi, 'com.tsudev.laban');
    expect(c.phienBan, phienBanApp);
  });

  test('Gradle khớp gói Dart (applicationId + hậu tố flavor)', () {
    final g = File('android/app/build.gradle.kts').readAsStringSync();
    expect(g, contains('applicationId = "${cauHinhMienPhi(Flavor.prod).goi}"'));
    expect(g, contains('applicationIdSuffix = ".dev"'));
    expect(g, contains('applicationIdSuffix = ".stg"'));
  });
}
