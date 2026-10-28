import 'package:flutter_test/flutter_test.dart';
import 'package:location_feature/location_feature.dart';

import 'ho_tro.dart';

void main() {
  group('UTM so PROJ', () {
    for (final m in mau('utm')) {
      final vi = so(m['viDo']);
      final kinh = so(m['kinhDo']);
      test('$vi, $kinh', () {
        final u = sangUtm(vi, kinh)!;
        expect(u.vung, m['vung']);
        expect(u.dong, closeTo(so(m['dong']), 0.001));
        expect(u.bac, closeTo(so(m['bac']), 0.001));
      });
    }
  });

  test('MGRS khớp GeoTrans (NGA) từng chuỗi', () {
    var khop = 0;
    final lech = <String>[];
    for (final m in mau('utm')) {
      final kq = sangMgrs(so(m['viDo']), so(m['kinhDo']));
      if (kq == m['mgrs']) {
        khop++;
      } else {
        lech.add('${m['viDo']},${m['kinhDo']}: $kq != ${m['mgrs']}');
      }
    }
    expect(lech, isEmpty);
    expect(khop, mau('utm').length);
  });

  test('ngoài phạm vi UTM (vùng cực) trả null', () {
    expect(sangUtm(84, 10), isNull);
    expect(sangUtm(-80.1, 10), isNull);
    expect(dinhDangToaDo(DinhDangToaDo.mgrs, 85, 0), isNull);
    expect(dinhDangToaDo(DinhDangToaDo.dd, 85, 0), isNotNull);
  });

  test('ngoại lệ múi Na Uy / Svalbard', () {
    expect(vungUtm(60, 5), 32);
    expect(vungUtm(60, 2), 31);
    expect(vungUtm(78, 8), 31);
    expect(vungUtm(78, 10), 33);
    expect(vungUtm(78, 22), 35);
    expect(vungUtm(78, 34), 37);
    expect(vungUtm(0, 180), 1);
  });

  test('định dạng hiển thị', () {
    expect(dinhDangDD(21.0285114, 105.8048172), '21.028511, 105.804817');
    expect(dinhDangDMS(21.028511, 105.804817), '21°01\'42.6"N 105°48\'17.3"E');
    expect(dinhDangDMS(-33.8688, -0.1246), '33°52\'07.7"S 0°07\'28.6"W');
    // 59,96" nhớ sang phút, không hiện 60,0".
    expect(
      dinhDangMotTrucDMS(10 + 59.99 / 3600, laViDo: true),
      '10°01\'00.0"N',
    );
    expect(dinhDangUtm(21.028511, 105.804817), '48Q 583629 2325513');
    expect(dinhDangMgrs(21.028511, 105.804817), '48Q WJ 83629 25513');
    expect(dinhDangMgrs(10, 9.5), startsWith('32P '));
    expect(sangMgrs(12.14, -178.28), startsWith('01P'));
    expect(sangMgrs(21.028511, 105.804817, soChuSo: 3), '48QWJ836255');
    expect(sangUtm(-33.8688, 151.2093)!.bacBanCau, isFalse);
  });
}
