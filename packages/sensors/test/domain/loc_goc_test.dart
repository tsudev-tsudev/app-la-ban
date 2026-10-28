import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

void main() {
  group('KalmanGoc', () {
    test('đi qua 350° -> 10° không vòng qua 180°', () {
      final k = KalmanGoc();
      expect(k.goc, isNull);
      for (var i = 0; i <= 40; i++) {
        final z = chuanHoaDo(350 + i * 0.5);
        final g = k.capNhat(z, 0.01, phuongSai: 1);
        // Không bao giờ rơi vào nửa nam.
        expect(g < 90 || g > 270, isTrue, reason: 'bước $i: $g');
      }
      expect(hieuGoc(k.goc!, 10).abs(), lessThan(1));
      expect(k.tocDo, greaterThan(0));
      k.datLai();
      expect(k.goc, isNull);
    });

    test('giảm nhiễu đo khi đứng yên', () {
      final r = math.Random(3);
      final k = KalmanGoc();
      final ra = <double>[];
      for (var i = 0; i < 500; i++) {
        final z = 90 + (r.nextDouble() - 0.5) * 6;
        ra.add(k.capNhat(z, 0.01, phuongSai: 9));
      }
      final cuoi = ra.sublist(300);
      expect(thongKeVong(cuoi).doLechChuan, lessThan(1));
    });
  });

  group('LocThichUng', () {
    test('rung nhỏ bị làm mượt, quay lớn bám nhanh', () {
      final l = LocThichUng();
      expect(l.alpha(0.5, 0.016), lessThan(l.alpha(30, 0.016)));
      expect(l.alpha(30, 0.016), greaterThan(0.4));
      expect(l.alpha(5, 0), 0);
    });

    test('bước nhảy 90°: ~90% sau 0,1 s, sai < 1° sau 0,5 s', () {
      final l = LocThichUng()..capNhat(0, 0);
      final ra = [for (var i = 0; i < 31; i++) l.capNhat(90, 0.016)];
      expect(ra[5], greaterThan(80));
      expect(ra.last, closeTo(90, 1));
    });

    test('dự báo theo tốc độ: xoay đều 60°/s không trễ', () {
      final l = LocThichUng()..capNhat(0, 0);
      var y = 0.0;
      for (var i = 1; i <= 100; i++) {
        y = l.capNhat(chuanHoaDo(i * 0.96), 0.016, tocDo: 60);
      }
      expect(hieuGoc(y, 96).abs(), lessThan(0.5));
    });

    test('qua 359° -> 1° đi đường ngắn', () {
      final l = LocThichUng()..capNhat(359, 0);
      final y = l.capNhat(1, 0.016);
      expect(y > 358 || y < 2, isTrue, reason: '$y');
      l.datLai();
      expect(l.giaTri, isNull);
    });
  });
}
