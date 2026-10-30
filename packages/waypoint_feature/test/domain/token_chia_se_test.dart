import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

const d = DiemMoc(
  id: 'x',
  ten: 'Hồ Gươm',
  viDo: 21.0285111,
  kinhDo: 105.8521822,
  caoDo: 12.3,
  ghiChu: 'Gặp ở cổng đền Ngọc Sơn',
  taoLuc: 0,
  suaLuc: 0,
);

/// Vector dùng chung với test landing (web/landing/test/diem-chia-se.test.ts)
/// - đổi định dạng token phải đổi cả hai nơi.
const vectorDayDu =
    'AQMMiLI3PxfC3mtJ0gAAAAB7C0jhu5MgR8awxqFtI0fhurdwIOG7nyBj4buVbmcgxJHhu4Fu'
    'IE5n4buNYyBTxqFu8n1obQ';
const vectorToiGian = 'AQAAAAAAAAAAAP____8BQRQuxN8';

void main() {
  test('crc32 chuẩn zlib', () {
    expect(crc32('123456789'.codeUnits), 0xCBF43926);
    expect(crc32([]), 0);
  });

  test('mã -> giải đúng (toạ độ 1e-7°, cao độ 0,1 m)', () {
    final t = maHoaToken(d, hetHan: 1800000000);
    expect(t, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    final g = giaiMaToken(t, bayGio: 1700000000);
    expect(g, (
      ten: 'Hồ Gươm',
      viDo: 21.0285111,
      kinhDo: 105.8521822,
      caoDo: 12.3,
      ghiChu: 'Gặp ở cổng đền Ngọc Sơn',
      hetHan: 1800000000,
    ));
  });

  test('vector cố định (khớp landing)', () {
    expect(maHoaToken(d, hetHan: 1800000000), vectorDayDu);
    const toiGian = DiemMoc(
      id: 'y',
      ten: 'A',
      viDo: 0,
      kinhDo: 0,
      taoLuc: 0,
      suaLuc: 0,
    );
    expect(maHoaToken(toiGian, hetHan: 0xffffffff), vectorToiGian);
    expect(giaiMaToken(vectorToiGian, bayGio: 0).ten, 'A');
  });

  test('cắt ghi chú dài, toạ độ âm', () {
    final t = maHoaToken(
      d.copyWith(viDo: -33.8688197, kinhDo: -151.2092955, ghiChu: 'x' * 500),
      hetHan: 10,
    );
    final g = giaiMaToken(t, bayGio: 10);
    expect((g.viDo, g.kinhDo), (-33.8688197, -151.2092955));
    expect(g.ghiChu.length, ghiChuChiaSeToiDa);
  });

  test('hết hạn / hỏng / sửa 1 bit / bản mới hơn', () {
    final t = maHoaToken(d, hetHan: 100);
    expect(
      () => giaiMaToken(t, bayGio: 101),
      throwsA(const NgoaiLeToken(LoiToken.hetHan)),
    );
    for (final hong in [
      '',
      'abc',
      '%%%',
      t.substring(0, t.length - 3),
      t.replaceRange(10, 11, t[10] == 'A' ? 'B' : 'A'),
      'A' * 5000,
    ]) {
      expect(
        () => giaiMaToken(hong, bayGio: 0),
        throwsA(const NgoaiLeToken(LoiToken.hong)),
        reason: hong,
      );
    }
    // Byte phiên bản = 2 với CRC tính lại đúng -> link của bản app mới hơn.
    final b = base64Url.decode(base64Url.normalize(vectorToiGian));
    final than = [2, ...b.sublist(1, b.length - 4)];
    final c = crc32(than);
    final v2 = base64Url
        .encode([...than, c >> 24, (c >> 16) & 255, (c >> 8) & 255, c & 255])
        .replaceAll('=', '');
    expect(
      () => giaiMaToken(v2, bayGio: 0),
      throwsA(const NgoaiLeToken(LoiToken.phienBanLa)),
    );
  });

  test('tokenTuLink', () {
    expect(tokenTuLink('https://compass.tsudev.com/w/AbC_-1'), 'AbC_-1');
    expect(tokenTuLink('/w/AbC/?utm=1#x'), 'AbC');
    expect(tokenTuLink('https://compass.tsudev.com/x/AbC'), isNull);
    expect(tokenTuLink('/w/'), isNull);
  });
}
