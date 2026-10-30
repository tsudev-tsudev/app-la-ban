import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

import '../mo_phong.dart';

void main() {
  group('Quat', () {
    test('quay 90° quanh Z đưa X thành Y', () {
      final q = Quat.quanhTruc(const Vec3(0, 0, 1), doSangRad(90));
      final v = q.xoay(const Vec3(1, 0, 0));
      expect(v.x, closeTo(0, 1e-12));
      expect(v.y, closeTo(1, 1e-12));
      expect(q.xoayNguoc(v).x, closeTo(1, 1e-12));
    });

    test('tuMaTran khôi phục quaternion ở mọi nhánh', () {
      for (final q in [
        tuGoc(10, 20, 30),
        tuGoc(179, -60, 80),
        Quat.quanhTruc(const Vec3(1, 0, 0), 3.1),
        Quat.quanhTruc(const Vec3(0, 1, 0), 3.1),
        Quat.quanhTruc(const Vec3(0, 0, 1), 3.1),
      ]) {
        final p = Quat.tuMaTran(q.maTran);
        const v = Vec3(0.3, -0.5, 0.8);
        final a = q.xoay(v);
        final b = p.xoay(v);
        expect((a - b).doDai, lessThan(1e-9), reason: '$q');
      }
    });

    test('chuẩn hoá quaternion 0 thành đơn vị, vectơ 0 không có donVi', () {
      expect(const Quat(0, 0, 0, 0).chuanHoa.w, 1);
      expect(Vec3.zero.donVi, isNull);
      expect((-const Vec3(1, 2, 3)).x, -1);
    });
  });

  group('tuTheTuQuat', () {
    test('khôi phục phương vị / ngóc / nghiêng', () {
      for (final (pv, doc, lan) in [
        (0.0, 0.0, 0.0),
        (45.0, 10.0, -5.0),
        (200.0, -30.0, 20.0),
        (359.5, 40.0, 0.0),
      ]) {
        final t = tuTheTuQuat(tuGoc(pv, doc, lan));
        expect(saiSo(t.phuongVi, pv), lessThan(1e-6), reason: '$pv');
        expect(t.doc, closeTo(doc, 1e-6));
        // Hai phép quay nối tiếp: mép phải nâng lên sin(lan)·cos(ngóc).
        final lanDo = radSangDo(
          math.asin(math.sin(doSangRad(lan)) * math.cos(doSangRad(doc))),
        );
        expect(t.lan, closeTo(lanDo, 1e-6));
        expect(t.theoCamera, isFalse);
      }
    });

    test('màn hình xoay ngang: mép trên lệch 90° so với đỉnh máy', () {
      final q = tuGoc(30, 0, 0);
      expect(
        tuTheTuQuat(q, xoay: XoayManHinh.r90).phuongVi,
        closeTo(120, 1e-6),
      );
      expect(
        tuTheTuQuat(q, xoay: XoayManHinh.r180).phuongVi,
        closeTo(210, 1e-6),
      );
      expect(
        tuTheTuQuat(q, xoay: XoayManHinh.r270).phuongVi,
        closeTo(300, 1e-6),
      );
    });

    test('dựng đứng: theo hướng camera sau, liền mạch khi qua 45°', () {
      final dung = tuTheTuQuat(tuGoc(80, 85, 0));
      expect(dung.theoCamera, isTrue);
      expect(saiSo(dung.phuongVi, 80), lessThan(1e-6));
      final truoc = tuTheTuQuat(tuGoc(80, 44.9, 0));
      final sau = tuTheTuQuat(tuGoc(80, 45.1, 0));
      expect(truoc.theoCamera, isFalse);
      expect(sau.theoCamera, isTrue);
      expect(saiSo(truoc.phuongVi, sau.phuongVi), lessThan(0.01));
    });
  });

  test('góc ngóc camera sau: ngửa ra sau là nhìn lên, có dấu', () {
    for (final (doc, ngoc) in [(90.0, 0.0), (100.0, 10.0), (75.0, -15.0)]) {
      final t = tuTheTuQuat(tuGoc(30, doc, 0));
      expect(t.theoCamera, isTrue);
      expect(t.ngocCamera, closeTo(ngoc, 1e-6));
      expect(saiSo(t.phuongVi, 30), lessThan(1e-6));
    }
  });

  group('quatTuGiaTocTu (bù nghiêng)', () {
    test('máy nghiêng vẫn ra đúng phương vị', () {
      for (final (pv, doc, lan) in [
        (0.0, 0.0, 0.0),
        (90.0, 25.0, -15.0),
        (271.0, -35.0, 30.0),
      ]) {
        final q = tuGoc(pv, doc, lan);
        final r = quatTuGiaTocTu(q.xoayNguoc(trongLuc), q.xoayNguoc(tuHaNoi))!;
        expect(saiSo(tuTheTuQuat(r).phuongVi, pv), lessThan(1e-6));
        expect(tuTheTuQuat(r).doc, closeTo(doc, 1e-6));
      }
    });

    test('rơi tự do / từ trường song song trọng lực -> null', () {
      expect(quatTuGiaTocTu(const Vec3(0, 0, 0.2), tuHaNoi), isNull);
      expect(quatTuGiaTocTu(trongLuc, const Vec3(0, 0, 40)), isNull);
    });

    test('vectơ quay Android: thiếu w thì tự tính', () {
      final q = tuGoc(123, 10, 5);
      final dau = q.w < 0 ? -1 : 1;
      final r = quatTuVectorQuay(q.x * dau, q.y * dau, q.z * dau);
      expect(saiSo(tuTheTuQuat(r).phuongVi, 123), lessThan(1e-6));
    });
  });

  test('độ cao khí áp chuẩn', () {
    expect(doCaoKhiAp(1013.25), closeTo(0, 1e-9));
    expect(doCaoKhiAp(899), closeTo(1000, 15));
  });
}
