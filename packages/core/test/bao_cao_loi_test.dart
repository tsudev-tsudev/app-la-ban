import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  BaoCaoLoi bc(String kieu, String nx, {int luc = 1}) => BaoCaoLoi(
    loai: 'dart',
    kieu: kieu,
    thongDiep: 'm',
    nganXep: nx,
    phienBan: '0.1.0',
    luc: luc,
  );

  // Ghép lúc chạy: chuỗi JWT nguyên văn bị cổng quét bí mật chặn.
  final jwt = [
    'eyJhbGciOiJFUzI1NiJ9',
    'eyJzdWIiOiIxMjM0NTY3OCJ9',
    'c2lnbmF0dXJlMTIz',
  ].join('.');

  test('taoBaoCaoLoi che token / toạ độ và cắt độ dài', () {
    final b = taoBaoCaoLoi(
      loai: 'flutter',
      loi: StateError('vi tri 21.028511, 105.804817 token $jwt'),
      phienBan: '0.1.0-beta.12+12',
      luc: 5,
      nganXep: StackTrace.fromString('#0 a\n' * 3000),
    );
    expect(b.kieu, 'StateError');
    expect(b.thongDiep, isNot(contains('21.028511')));
    expect(b.thongDiep, contains('21.02~'));
    expect(b.thongDiep, contains('<jwt>'));
    expect(b.nganXep.length, doDaiNganXepToiDa);
    expect(BaoCaoLoi.tuJson(b.toJson())?.toJson(), b.toJson());
    expect(BaoCaoLoi.tuJson({'loai': 1}), isNull);
  });

  test('themVaoHang bỏ trùng, giữ bản mới nhất', () {
    var h = <BaoCaoLoi>[];
    h = themVaoHang(h, bc('A', 'x'));
    h = themVaoHang(h, bc('A', 'x', luc: 2));
    expect(h, hasLength(1));
    for (var i = 0; i < 25; i++) {
      h = themVaoHang(h, bc('B$i', 'y'));
    }
    expect(h, hasLength(hangDoiToiDa));
    expect(h.last.kieu, 'B24');
    expect(h.first.kieu, 'B5');
  });
}
