import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

void main() {
  group('danhGiaTinCay', () {
    test('theo độ chính xác OS', () {
      expect(
        danhGiaTinCay(os: DoChinhXacOs.cao, nhieuTu: false).muc,
        MucTinCay.cao,
      );
      expect(
        danhGiaTinCay(os: DoChinhXacOs.trungBinh, nhieuTu: false).muc,
        MucTinCay.trungBinh,
      );
      final thap = danhGiaTinCay(os: DoChinhXacOs.thap, nhieuTu: false);
      expect(thap.muc, MucTinCay.thap);
      expect(thap.canHieuChuan, isTrue);
      expect(
        danhGiaTinCay(os: DoChinhXacOs.khongTinCay, nhieuTu: true).canHieuChuan,
        isTrue,
      );
    });

    test('nhiễu từ -> thấp nhưng không đòi hiệu chuẩn (rời nguồn nhiễu)', () {
      final d = danhGiaTinCay(os: DoChinhXacOs.cao, nhieuTu: true);
      expect(d.muc, MucTinCay.thap);
      expect(d.nhieuTu, isTrue);
      expect(d.canHieuChuan, isFalse);
    });

    test('rung > 5° khi đứng yên hạ một bậc', () {
      expect(
        danhGiaTinCay(os: DoChinhXacOs.cao, nhieuTu: false, doLechChuan: 8).muc,
        MucTinCay.trungBinh,
      );
      expect(
        danhGiaTinCay(os: DoChinhXacOs.cao, nhieuTu: false, doLechChuan: 2).muc,
        MucTinCay.cao,
      );
    });
  });

  group('TheoDoiNhieuTu', () {
    test('ngoài dải Trái Đất là nhiễu, nền không học giá trị lạ', () {
      final t = TheoDoiNhieuTu();
      expect(t.nap(120), isTrue);
      expect(t.nen, isNull);
      expect(t.nap(45), isFalse);
      expect(t.nen, 45);
    });

    test('đổi đột ngột > 20% là nhiễu, đổi chậm thì nền bám theo', () {
      final t = TheoDoiNhieuTu()..nap(45);
      expect(t.nap(46), isFalse);
      expect(t.nap(60), isTrue);
      expect(t.nen, lessThan(46));
      t.datLai();
      expect(t.nen, isNull);
    });
  });

  test('PhatHienDungYen: yên 3 s mới đổi, động mạnh đổi ngay', () {
    final p = PhatHienDungYen();
    var doi = false;
    for (var i = 0; i < 299; i++) {
      doi = p.nap(0.01, 0.01) || doi;
    }
    expect(p.dungYen, isFalse);
    expect(p.nap(0.01, 0.02), isTrue);
    expect(p.dungYen, isTrue);
    expect(p.nap(0.05, 0.01), isFalse, reason: 'vùng trễ: chưa đủ mạnh');
    expect(p.nap(0.2, 0.01), isTrue);
    expect(p.dungYen, isFalse);
    expect(doi, isFalse);
  });
}
