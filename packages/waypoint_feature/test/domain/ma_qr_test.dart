import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// Ảnh chụp từ thư viện `qrcode` 1.5 (npm) - chế độ byte, mức M; sinh lại:
/// xem đầu tệp ma_qr.dart.
void main() {
  final mau = (jsonDecode(
    File('test/du_lieu/qr_npm.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();

  for (final m in mau) {
    final noiDung = m['noiDung']! as String;
    final mat = m['mat'] as int?;
    test(
      'khớp qrcode npm: ${noiDung.length} ký tự, mặt nạ ${mat ?? 'tự chọn'}',
      () {
        final q = maHoaQr(noiDung, mat: mat);
        expect(q.phienBan, m['phienBan']);
        expect(q.mat, m['matChon']);
        final o = (m['o']! as List).cast<String>();
        expect(q.canh, o.length);
        for (var y = 0; y < q.canh; y++) {
          final hang = StringBuffer();
          for (var x = 0; x < q.canh; x++) {
            hang.write(q.toi(x, y) ? '1' : '0');
          }
          expect(hang.toString(), o[y], reason: 'hàng $y');
        }
      },
    );
  }

  test('quá dung lượng -> ArgumentError', () {
    expect(() => maHoaQr('x' * 2400), throwsArgumentError);
    expect(maHoaQr('x' * 2331).phienBan, 40);
  });
}
