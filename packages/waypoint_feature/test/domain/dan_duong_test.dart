import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

void main() {
  group('trễ hai ngưỡng dẫn đường (A9c)', () {
    test('đi thẳng: vào <= 10°, ra > 15°', () {
      expect(diThang(12, truoc: false), isFalse);
      expect(diThang(-9, truoc: false), isTrue);
      expect(diThang(12, truoc: true), isTrue);
      expect(diThang(-16, truoc: true), isFalse);
    });

    test('góc dao động 8° / 13°: chỉ dẫn đổi đúng một lần', () {
      var thang = false;
      var doi = 0;
      for (var i = 0; i < 100; i++) {
        final moi = diThang(i.isEven ? 13 : 8, truoc: thang);
        if (moi != thang) doi++;
        thang = moi;
      }
      expect(doi, 1);
    });

    test('đã tới: GPS nhiễu quanh bán kính không làm rời trạng thái', () {
      // Đích cách ~ 0,00018° vĩ độ (~20 m) về phía bắc.
      DanDuong tinh(double lechM, {required bool truoc}) => tinhDanDuong(
        viDo: 21 - lechM / 111320,
        kinhDo: 105,
        dichViDo: 21,
        dichKinhDo: 105,
        saiSoM: 20,
        daToiTruoc: truoc,
      );
      expect(tinh(19, truoc: false).daToi, isTrue);
      expect(tinh(24, truoc: false).daToi, isFalse);
      expect(tinh(24, truoc: true).daToi, isTrue);
      expect(tinh(34, truoc: true).daToi, isTrue);
      expect(tinh(36, truoc: true).daToi, isFalse);
    });
  });
}
