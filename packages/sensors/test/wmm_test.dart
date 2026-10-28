import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

/// Bảng giá trị thử chính thức WMM2025_TestValues.txt (NOAA, 100 điểm).
List<List<double>> docBangThu() =>
    File('test/du_lieu/WMM2025_TestValues.txt')
        .readAsLinesSync()
        .where((d) => d.trim().isNotEmpty && !d.startsWith('#'))
        .map((d) => d.trim().split(RegExp(r'\s+')).map(double.parse).toList())
        .toList();

void main() {
  final hs = HeSoWmm.wmm2025;

  test('đọc WMM2025 nhúng sẵn: bậc 12, gốc 2025.0', () {
    expect(hs.ten, 'WMM-2025');
    expect(hs.namGoc, 2025.0);
    expect(hs.bac, 12);
    expect(hs.namHetHan, 2030.0);
  });

  test('100 điểm thử NOAA: độ lệch < 0,2° (cổng A3), X / Y / Z < 1 nT', () {
    final bang = docBangThu();
    expect(bang, hasLength(100));
    var lechMax = 0.0;
    for (final r in bang) {
      final kq = tinhTuTruong(
        hs,
        nam: r[0],
        doCaoKm: r[1],
        viDo: r[2],
        kinhDo: r[3],
      );
      final moTa = 'điểm $r';
      // NOAA làm tròn D / I tới 0,01°.
      final lech = hieuGoc(kq.doLech, r[4]).abs();
      if (lech > lechMax) lechMax = lech;
      expect(lech, lessThan(0.006), reason: moTa);
      expect(kq.doKhuynh, closeTo(r[5], 0.006), reason: moTa);
      expect(kq.h, closeTo(r[6], 1), reason: moTa);
      expect(kq.x, closeTo(r[7], 1), reason: moTa);
      expect(kq.y, closeTo(r[8], 1), reason: moTa);
      expect(kq.z, closeTo(r[9], 1), reason: moTa);
      expect(kq.f, closeTo(r[10], 1), reason: moTa);
      expect(kq.ngoaiHan, isFalse);
    }
    expect(lechMax, lessThan(0.2));
  });

  test('Việt Nam: Hà Nội / TP.HCM lệch tây nhỏ, cường độ hợp lý', () {
    for (final (viDo, kinhDo) in [(21.03, 105.85), (10.78, 106.70)]) {
      final kq = tinhTuTruong(hs, viDo: viDo, kinhDo: kinhDo, nam: 2026.8);
      expect(kq.doLech, inInclusiveRange(-2.0, 0.5));
      expect(kq.f / 1000, inInclusiveRange(38.0, 50.0)); // µT
    }
  });

  test('cực: kẹp vĩ độ, không NaN', () {
    for (final v in [90.0, -90.0]) {
      final kq = tinhTuTruong(hs, viDo: v, kinhDo: 10, nam: 2026);
      expect(kq.doLech.isFinite, isTrue);
      expect(kq.f.isFinite, isTrue);
    }
  });

  test('ngoài khoảng hiệu lực -> cờ ngoaiHan', () {
    expect(
      tinhTuTruong(hs, viDo: 21, kinhDo: 105, nam: 2030.5).ngoaiHan,
      isTrue,
    );
    expect(
      tinhTuTruong(hs, viDo: 21, kinhDo: 105, nam: 2024.9).ngoaiHan,
      isTrue,
    );
  });

  test('namThapPhan', () {
    expect(namThapPhan(DateTime.utc(2025)), 2025.0);
    expect(namThapPhan(DateTime.utc(2025, 7, 2, 12)), closeTo(2025.5, 1e-9));
    expect(namThapPhan(DateTime.utc(2028, 12, 31, 24)), 2029.0);
  });

  group('tuCof từ chối dữ liệu hỏng', () {
    for (final (ten, cof) in [
      ('rỗng', ''),
      ('dòng đầu lạ', 'abc\n'),
      ('thiếu tên', '2025.0\n'),
      ('không hệ số', '2025.0 WMM 1/1/2025\n9999\n'),
      ('n = 0', '2025.0 WMM x\n 0 0 1 2 3 4\n'),
      ('m > n', '2025.0 WMM x\n 1 2 1 2 3 4\n'),
      ('thiếu cột', '2025.0 WMM x\n 1 0 1 2 3\n'),
      ('không phải số', '2025.0 WMM x\n 1 0 1 a 3 4\n'),
      ('NaN', '2025.0 WMM x\n 1 0 NaN 0 0 0\n'),
    ]) {
      test(ten, () {
        expect(() => HeSoWmm.tuCof(cof), throwsFormatException);
      });
    }
  });

  test(
    'tuCof đọc COF tối giản (lưỡng cực) - độ lệch 0 trên kinh tuyến gốc',
    () {
      final hs = HeSoWmm.tuCof('2020.0 THU 1/1/2020\n 1 0 -30000 0 0 0\n');
      final kq = tinhTuTruong(hs, viDo: 0, kinhDo: 0, nam: 2021);
      expect(kq.doLech, closeTo(0, 1e-9));
      expect(kq.x, greaterThan(0));
    },
  );
}
