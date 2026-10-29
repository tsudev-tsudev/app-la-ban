import 'package:network/network.dart';
import 'package:test/test.dart';

void main() {
  test('pin tính lại từ PEM khớp pin sinh bởi openssl / node (cả 5 CA)', () {
    expect(gocTinCay, hasLength(greaterThanOrEqualTo(2)));
    for (final g in gocTinCay) {
      expect(pinCuaPem(g.pem), g.pin, reason: g.ten);
    }
    // GTS Root R4 = CA đang phục vụ compass-api (đối chiếu 30/10/2026).
    expect(
      gocTinCay.map((g) => g.pin),
      contains('mEflZT5enoR1FuXLgYYGqnVEoZvmf9c2bVBpiOjYQ0c='),
    );
  });

  test('mọi CA đóng gói còn hạn >= 5 năm và nạp được vào SecurityContext', () {
    final sau5Nam = DateTime.now().add(const Duration(days: 5 * 365));
    for (final g in gocTinCay) {
      expect(DateTime.parse(g.het).isAfter(sau5Nam), isTrue, reason: g.ten);
    }
    expect(() => nguCanhGhim(gocMacDinh), returnsNormally);
    expect(() => nguCanhGhim(const []), throwsArgumentError);
  });

  test('PEM hỏng -> null', () {
    expect(pinCuaPem('khong phai pem'), isNull);
    expect(
      pinCuaPem('-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----'),
      isNull,
    );
    final cat = gocTinCay.first.pem.replaceRange(80, 400, '');
    expect(pinCuaPem(cat), isNull);
  });
}
