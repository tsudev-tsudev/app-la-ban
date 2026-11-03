import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 11, 3);
DateTime _ms(int ms) => _t0.add(Duration(milliseconds: ms));

void main() {
  group('TreCanhBao', () {
    test('bật ngay khi vượt ngưỡng bật', () {
      final s = const TreCanhBao().capNhat(
        vuotNguongBat: true,
        duoiNguongTat: false,
        luc: _t0,
      );
      expect(s.dangBat, isTrue);
      expect(s.batLuc, _t0);
    });

    test('vùng giữa hai ngưỡng: không bật mới, không tắt', () {
      var s = const TreCanhBao().capNhat(
        vuotNguongBat: false,
        duoiNguongTat: false,
        luc: _t0,
      );
      expect(s.dangBat, isFalse);
      s = s.capNhat(vuotNguongBat: true, duoiNguongTat: false, luc: _t0);
      for (var ms = 0; ms < 10000; ms += 100) {
        s = s.capNhat(vuotNguongBat: false, duoiNguongTat: false, luc: _ms(ms));
        expect(s.dangBat, isTrue);
      }
    });

    test('giữ tối thiểu dù tín hiệu yên ngay', () {
      var s = const TreCanhBao().capNhat(
        vuotNguongBat: true,
        duoiNguongTat: false,
        luc: _t0,
      );
      for (var ms = 100; ms < 2000; ms += 100) {
        s = s.capNhat(vuotNguongBat: false, duoiNguongTat: true, luc: _ms(ms));
        expect(s.dangBat, isTrue, reason: '$ms ms');
      }
      s = s.capNhat(vuotNguongBat: false, duoiNguongTat: true, luc: _ms(2000));
      expect(s.dangBat, isFalse);
      expect(s.batLuc, isNull);
      expect(s.yenTu, isNull);
    });

    test('phải yên liên tục mới tắt - một mẫu nhiễu đặt lại bộ đếm', () {
      var s = const TreCanhBao().capNhat(
        vuotNguongBat: true,
        duoiNguongTat: false,
        luc: _t0,
      );
      s = s.capNhat(vuotNguongBat: false, duoiNguongTat: true, luc: _ms(2500));
      s = s.capNhat(vuotNguongBat: false, duoiNguongTat: false, luc: _ms(3000));
      s = s.capNhat(vuotNguongBat: false, duoiNguongTat: true, luc: _ms(3100));
      s = s.capNhat(vuotNguongBat: false, duoiNguongTat: true, luc: _ms(3800));
      expect(s.dangBat, isTrue);
      s = s.capNhat(vuotNguongBat: false, duoiNguongTat: true, luc: _ms(3900));
      expect(s.dangBat, isFalse);
    });

    test('tín hiệu dao động 5 Hz quanh ngưỡng: đổi trạng thái <= 1 lần', () {
      var s = const TreCanhBao();
      var doi = 0;
      for (var ms = 0; ms < 20000; ms += 20) {
        final pha = (ms ~/ 100).isEven;
        final truoc = s.dangBat;
        s = s.capNhat(vuotNguongBat: pha, duoiNguongTat: !pha, luc: _ms(ms));
        if (s.dangBat != truoc) doi++;
      }
      expect(doi, 1);
      expect(s.dangBat, isTrue);
    });
  });

  group('OnDinhBac', () {
    test('xấu đi đổi ngay, tốt lên phải chờ', () {
      var s = const OnDinhBac(2).capNhat(0, _t0);
      expect(s.bac, 0);
      s = s.capNhat(2, _ms(500));
      expect(s.bac, 0, reason: 'chưa đủ giữ tối thiểu');
      s = s.capNhat(2, _ms(1600));
      expect(s.bac, 0, reason: 'ứng viên đủ 1,1 s nhưng mới giữ 1,6 s');
      s = s.capNhat(2, _ms(2400));
      expect(s.bac, 2);
    });

    test('dao động cao / thấp mỗi 100 ms: nhãn đổi đúng một lần', () {
      var s = const OnDinhBac(2);
      var doi = 0;
      for (var ms = 0; ms < 10000; ms += 100) {
        final truoc = s.bac;
        s = s.capNhat((ms ~/ 100).isEven ? 0 : 2, _ms(ms));
        if (s.bac != truoc) doi++;
      }
      expect(doi, 1);
      expect(s.bac, 0);
    });

    test('ổn định lại: lên tới bậc thấp nhất trong lúc chờ', () {
      var s = OnDinhBac(0, doiLuc: _t0);
      s = s.capNhat(2, _ms(3000));
      s = s.capNhat(1, _ms(3500));
      s = s.capNhat(2, _ms(3900));
      expect(s.bac, 0);
      s = s.capNhat(2, _ms(4000));
      expect(s.bac, 1);
      s = s.capNhat(2, _ms(6000));
      expect(s.bac, 1);
      s = s.capNhat(2, _ms(7000));
      expect(s.bac, 2);
    });
  });

  group('LbOCoDinh', () {
    Widget dung(int chiSo, {bool giam = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: giam),
        child: Scaffold(
          body: Column(
            children: [
              LbOCoDinh(
                key: const Key('o'),
                chiSo: chiSo,
                phuongAn: const [Text('ngắn'), Text('dài\nhai dòng')],
              ),
              const Text('bên dưới', key: Key('duoi')),
            ],
          ),
        ),
      ),
    );

    testWidgets('đổi phương án không đổi kích thước, không đẩy layout', (
      tester,
    ) async {
      await tester.pumpWidget(dung(0));
      final co = tester.getSize(find.byKey(const Key('o')));
      final duoi = tester.getTopLeft(find.byKey(const Key('duoi')));
      for (var i = 1; i < 10; i++) {
        await tester.pumpWidget(dung(i % 2));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.getSize(find.byKey(const Key('o'))), co);
        expect(tester.getTopLeft(find.byKey(const Key('duoi'))), duoi);
      }
    });

    testWidgets('chỉ phương án đang hiện có ngữ nghĩa; Reduce motion tức thì', (
      tester,
    ) async {
      await tester.pumpWidget(dung(1, giam: true));
      expect(find.bySemanticsLabel('ngắn'), findsNothing);
      expect(find.bySemanticsLabel('dài\nhai dòng'), findsOneWidget);
      final mo = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('dài\nhai dòng'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(mo.duration, Duration.zero);
      expect(mo.opacity, 1);
    });
  });
}
