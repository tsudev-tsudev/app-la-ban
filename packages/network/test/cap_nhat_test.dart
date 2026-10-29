import 'package:network/network.dart';
import 'package:test/test.dart';

void main() {
  test('bắt buộc > khuyến nghị > bản mới > không', () {
    expect(quyetDinhCapNhat(build: 5), CapNhat.khong);
    expect(
      quyetDinhCapNhat(build: 5, toiThieu: 6, khuyenNghi: 7),
      CapNhat.batBuoc,
    );
    expect(
      quyetDinhCapNhat(build: 6, toiThieu: 6, khuyenNghi: 7),
      CapNhat.khuyenNghi,
    );
    expect(
      quyetDinhCapNhat(build: 7, toiThieu: 6, khuyenNghi: 7),
      CapNhat.khong,
    );
    expect(quyetDinhCapNhat(build: 5, banMoiNhat: 6), CapNhat.khuyenNghi);
    expect(quyetDinhCapNhat(build: 6, banMoiNhat: 6), CapNhat.khong);
    expect(
      quyetDinhCapNhat(build: 9, toiThieu: 1, khuyenNghi: 1, banMoiNhat: 8),
      CapNhat.khong,
    );
  });
}
