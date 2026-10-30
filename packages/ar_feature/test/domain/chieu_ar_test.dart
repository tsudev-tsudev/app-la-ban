import 'package:ar_feature/ar_feature.dart';
import 'package:flutter_test/flutter_test.dart';

const TruongNhin _tn = (ngang: 60.0, doc: 90.0);

DiemManHinh? _chieu(
  double phuongVi, {
  double ngoc = 0,
  TuTheCamera camera = (phuongVi: 0, ngoc: 0, lan: 0),
}) => chieuLenKhung(
  phuongVi: phuongVi,
  ngoc: ngoc,
  camera: camera,
  truongNhin: _tn,
  rong: 400,
  cao: 800,
);

void main() {
  group('chieuLenKhung', () {
    test('hướng camera đang nhìn -> giữa khung', () {
      final d = _chieu(123, camera: (phuongVi: 123, ngoc: 0, lan: 0))!;
      expect(d.x, closeTo(200, 1e-9));
      expect(d.y, closeTo(400, 1e-9));
    });

    test('lệch nửa trường nhìn -> đúng mép khung', () {
      expect(_chieu(30)!.x, closeTo(400, 1e-6));
      expect(_chieu(-30)!.x, closeTo(0, 1e-6));
      expect(_chieu(0, ngoc: 45)!.y, closeTo(0, 1e-6));
    });

    test('camera ngóc lên -> chân trời tụt xuống dưới tâm', () {
      final d = _chieu(0, camera: (phuongVi: 0, ngoc: 10, lan: 0))!;
      expect(d.x, closeTo(200, 1e-9));
      expect(d.y, greaterThan(400));
    });

    test('mép phải nâng lên -> điểm bên phải chân trời trôi xuống', () {
      final d = _chieu(20, camera: (phuongVi: 0, ngoc: 0, lan: 15))!;
      expect(d.x, greaterThan(200));
      expect(d.y, greaterThan(400));
    });

    test('sau lưng camera -> null; qua 0/360 vẫn liền', () {
      expect(_chieu(180), isNull);
      final a = _chieu(355, camera: (phuongVi: 5, ngoc: 0, lan: 0))!;
      expect(a.x, lessThan(200));
    });
  });

  test('truongNhinPhuKin: khung cao hơn ảnh -> cắt hai bên', () {
    // Ảnh dọc 3:4, khung 9:19,5 cao hơn -> trường nhìn ngang hẹp lại.
    final t = truongNhinPhuKin((ngang: 50, doc: 63), 3 / 4, 390, 844);
    expect(t.doc, 63);
    expect(t.ngang, lessThan(50));
    final r = truongNhinPhuKin((ngang: 50, doc: 63), 3 / 4, 600, 600);
    expect(r.ngang, 50);
    expect(r.doc, lessThan(63));
  });

  test('gocLechAr / gocNgocToi / vachChanTroi', () {
    expect(gocLechAr(350, 10), 20);
    expect(gocLechAr(10, 350), -20);
    expect(gocNgocToi(100, 100), closeTo(45, 1e-9));
    expect(gocNgocToi(0, 5), 0);
    final v = vachChanTroi(0, 30);
    expect(v, containsAll([0.0, 15.0, 45.0, 315.0, 345.0]));
    expect(v, isNot(contains(90.0)));
  });

  test('khoangCachGon', () {
    expect(khoangCachGon(42.4), (giaTri: 42.0, km: false));
    expect(khoangCachGon(456), (giaTri: 460.0, km: false));
    expect(khoangCachGon(1234), (giaTri: 1.2, km: true));
    expect(khoangCachGon(123456), (giaTri: 123.0, km: true));
  });
}
