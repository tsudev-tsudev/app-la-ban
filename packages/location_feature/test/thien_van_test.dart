import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:location_feature/location_feature.dart';

import 'ho_tro.dart';

void main() {
  DateTime? luc(Object? s) => s == null ? null : DateTime.parse(s as String);

  void soSuKien(
    SuKienNgay kq,
    Map<String, Object?> ref,
    DateTime tu,
    Duration saiSo,
  ) {
    final den = tu.add(const Duration(hours: 24));
    for (final (ten, giaTri) in [
      ('moc', kq.moc),
      ('lan', kq.lan),
      ('dinh', kq.dinh),
    ]) {
      final r = luc(ref[ten]);
      // ephem trả sự kiện KẾ TIẾP (có thể sau 24 giờ); hàm của ta chỉ xét
      // trong 24 giờ.
      if (r == null || r.isAfter(den.subtract(saiSo))) continue;
      expect(giaTri, isNotNull, reason: ten);
      expect(
        giaTri!.difference(r).abs(),
        lessThan(saiSo),
        reason: '$ten $giaTri vs $r',
      );
    }
  }

  for (final m in mau('thienVan')) {
    final vi = so(m['viDo']);
    final kinh = so(m['kinhDo']);
    final t = DateTime.parse(m['luc']! as String);
    test('$vi, $kinh lúc $t', () {
      final mt = m['matTroi']! as Map<String, Object?>;
      final s = viTriMatTroi(t, vi, kinh);
      expect(s.doCao, closeTo(so(mt['doCao']), 0.02));
      // Phương vị nhạy theo 1/cos(độ cao) khi gần thiên đỉnh.
      if (s.doCao.abs() < 89) {
        expect(
          hieuGoc(s.phuongVi, so(mt['phuongVi'])),
          lessThan(0.02 / math.cos(s.doCao * math.pi / 180)),
        );
      }
      soSuKien(suKienMatTroi(t, vi, kinh), mt, t, const Duration(minutes: 1));

      final ma = m['matTrang']! as Map<String, Object?>;
      final mo = viTriMatTrang(t, vi, kinh);
      expect(mo.doCao, closeTo(so(ma['doCao']), 0.1));
      if (mo.doCao.abs() < 89) {
        expect(
          hieuGoc(mo.phuongVi, so(ma['phuongVi'])),
          lessThan(0.1 / math.cos(mo.doCao * math.pi / 180)),
        );
      }
      expect(phaMatTrang(t).sang, closeTo(so(ma['sang']), 0.01));
      soSuKien(suKienMatTrang(t, vi, kinh), ma, t, const Duration(minutes: 2));
    });
  }

  test('khúc xạ: 0 dưới -1,5°, ~0,5° ở chân trời, nhỏ ở cao', () {
    expect(khucXa(-5), 0);
    expect(khucXa(0), closeTo(34 / 60, 0.02));
    expect(khucXa(45), lessThan(0.02));
  });

  test('ngày địa cực: không mọc / lặn', () {
    final hc = suKienMatTroi(DateTime.utc(2026, 6, 21), 80, 0);
    expect(hc.moc, isNull);
    expect(hc.lan, isNull);
    expect(hc.luonTren, isTrue);
    final dc = suKienMatTroi(DateTime.utc(2026, 12, 21), 80, 0);
    expect(dc.luonTren, isFalse);
    expect(dc.moc, isNull);
  });

  test('tên pha trăng', () {
    expect(tenPha((sang: 0, goc: 2)), TenPhaTrang.trangMoi);
    expect(tenPha((sang: 0.5, goc: 90)), TenPhaTrang.thuongHuyen);
    expect(tenPha((sang: 1, goc: 181)), TenPhaTrang.trangTron);
    expect(tenPha((sang: 0.5, goc: 270)), TenPhaTrang.haHuyen);
    expect(tenPha((sang: 0, goc: 350)), TenPhaTrang.trangMoi);
  });
}
