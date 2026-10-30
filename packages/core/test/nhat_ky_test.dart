import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('che JWT, Bearer, token dài, tọa độ chính xác', () {
    // JWT giả ghép lúc chạy: không để chuỗi dạng JWT nguyên văn trong repo
    // (máy quét bí mật như GitGuardian báo nhầm).
    final jwt = ['eyJ${'a' * 12}', 'eyJ${'b' * 12}', 'c' * 16].join('.');
    expect(cheNhatKy('token $jwt hết hạn'), 'token <jwt> hết hạn');
    expect(
      cheNhatKy('authorization: Bearer abc.def'),
      'authorization: Bearer <an>',
    );
    expect(cheNhatKy('refresh=${'x' * 43}'), 'refresh=<an>');
    expect(cheNhatKy('vị trí 21.028511, 105.804817'), 'vị trí 21.02~, 105.80~');
    expect(cheNhatKy('lat -33.86882'), 'lat -33.86~');
  });

  test('giữ nguyên chuỗi thường, mã lỗi, số ngắn', () {
    const s = 'dinhDanh.mang 503 thu lai sau 30 s, phien ban 0.1.0';
    expect(cheNhatKy(s), s);
    expect(cheNhatKy('góc 42.5°'), 'góc 42.5°');
  });

  test('NhatKy: release che, debug giữ nguyên', () {
    final ra = <String>[];
    void ghi(String s, {String ten = ''}) => ra.add('$ten|$s');
    NhatKy('rasp', ghi: ghi)('Bearer abc');
    NhatKy('rasp', che: false, ghi: ghi)('Bearer abc');
    expect(ra, ['rasp|Bearer <an>', 'rasp|Bearer abc']);
  });
}
