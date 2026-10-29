import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/dinh_danh.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/phien_ban.dart';

void main() {
  test('tách phiên bản app cho đăng ký thiết bị', () {
    expect(tachPhienBan('0.1.0-beta.4+4'), (ten: '0.1.0-beta.4', build: 4));
    expect(tachPhienBan('1.2.3'), (ten: '1.2.3', build: 1));
    expect(tachPhienBan(phienBanApp).build, greaterThan(0));
  });

  test('API theo flavor: staging / prod HTTPS, đúng tên miền một cấp', () {
    expect(Flavor.prod.apiGoc.toString(), 'https://compass-api.tsudev.com');
    expect(Flavor.staging.apiGoc.host, 'compass-api-stg.tsudev.com');
    expect(Flavor.staging.apiGoc.scheme, 'https');
    expect(Flavor.soDuAnCloud, 930761930572);
  });
}
