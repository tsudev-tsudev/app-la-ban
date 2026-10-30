import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

double dms(int d, int m, double s) => (d.abs() + m / 60 + s / 3600) * d.sign;

void main() {
  test('Vincenty: ví dụ Flinders Peak -> Buninyong (bài báo Vincenty 1975, '
      'số liệu Geoscience Australia trên WGS84)', () {
    final kq = tracDia(
      dms(-37, 57, 3.72030),
      dms(144, 25, 29.52440),
      dms(-37, 39, 10.15610),
      dms(143, 55, 35.38390),
    );
    expect(kq.khoangCachM, closeTo(54972.271, 0.001));
    expect(kq.phuongViDau, closeTo(dms(306, 52, 5.37), 1 / 3600 / 100 * 5));
    // Phương vị ngược 127°10'25,07" -> hướng đi tiếp = +180.
    expect(
      kq.phuongViCuoi,
      closeTo(dms(127, 10, 25.07) + 180, 1 / 3600 / 100 * 5),
    );
  });

  test('Hồ Gươm -> Nhà thờ Đức Bà (Sài Gòn) ~1.137 km, hướng nam-đông nam', () {
    final kq = tracDia(21.028511, 105.852182, 10.779783, 106.699018);
    expect(kq.khoangCachM, closeTo(1137000, 2000));
    expect(kq.phuongViDau, inInclusiveRange(170, 180));
  });

  test('trùng điểm -> 0; bắc thẳng -> 0°; đông trên xích đạo -> 90°', () {
    expect(tracDia(10, 20, 10, 20).khoangCachM, 0);
    expect(tracDia(10, 20, 11, 20).phuongViDau, closeTo(0, 1e-9));
    final xd = tracDia(0, 0, 0, 1);
    expect(xd.phuongViDau, closeTo(90, 1e-9));
    // 1° kinh độ trên xích đạo = a * pi / 180.
    expect(xd.khoangCachM, closeTo(111319.4908, 0.001));
  });

  test(
    'gần đối cực (Vincenty không hội tụ) -> dự phòng mặt cầu, không NaN',
    () {
      final kq = tracDia(0, 0, 0.5, 179.7);
      expect(kq.khoangCachM, closeTo(19.95e6, 0.1e6));
      expect(kq.phuongViDau.isFinite, isTrue);
      expect(kq.phuongViCuoi.isFinite, isTrue);
    },
  );

  test('gocLech / chuanHoa360', () {
    expect(gocLech(350, 10), 20);
    expect(gocLech(10, 350), -20);
    expect(gocLech(0, 180), 180);
    expect(gocLech(90, 90), 0);
    expect(chuanHoa360(-30), 330);
    expect(chuanHoa360(720.5), 0.5);
  });
}
