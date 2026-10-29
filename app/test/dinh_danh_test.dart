import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/dinh_danh.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/phien_ban.dart';
import 'package:security_sdk/security_sdk.dart';

void main() {
  _testThuLai();

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

final class _ApiTat implements ApiDinhDanh {
  bool mang = false;
  int goi = 0;

  @override
  Future<PhanHoiDinhDanh> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  }) async {
    goi++;
    if (!mang) throw const LoiKetNoi('SocketException');
    return switch (duongDan) {
      '/v1/device/challenge' => (status: 200, duLieu: {'thachThuc': 'T' * 43}),
      _ => (
        status: 201,
        duLieu: {
          'thietBiId': 'TB',
          'mucTin': 'device',
          'phien': {
            'accessToken': 'a',
            'hetHan': DateTime.now().millisecondsSinceEpoch + 900000,
            'refreshToken': 'r',
          },
        },
      ),
    };
  }
}

final class _Kho implements KhoTrangThai {
  @override
  Map<String, Object?> duLieu = {};

  @override
  void ghiDongBo(Map<String, Object?> moi) => duLieu = moi;

  @override
  Future<void> ghi(Map<String, Object?> moi) async => duLieu = moi;
}

final class _NenTang implements NenTangThietBi {
  @override
  Future<KhoaThietBi> khoaCongKhai() async =>
      (spki: Uint8List(91), mucBaoMat: 'tee');

  @override
  Future<Uint8List> ky(Uint8List duLieu) async => Uint8List(70);

  @override
  Future<String?> integrity(int soDuAn, String requestHash) async => null;

  @override
  Future<ThongTinMay> thongTin() async =>
      (model: 'm', heDieuHanh: '13', goi: 'com.tsudev.laban.stg');

  @override
  Future<void> xoaKhoa() async {}
}

void _testThuLai() {
  test(
    'mất mạng lúc mở app -> hẹn thử lại 30 s / 2 phút, có mạng -> đăng ký',
    () async {
      final api = _ApiTat();
      final hen = <Duration>[];
      void Function()? lanSau;
      final c = ChayDinhDanh(
        DichVuDinhDanh(
          api: api,
          nenTang: _NenTang(),
          tep: _Kho(),
          cauHinh: CauHinhDinhDanh(
            soDuAnCloud: 1,
            phienBanApp: '0.1.0',
            build: 1,
            ngonNgu: () => 'vi',
          ),
        ),
        hen: (d, f) {
          hen.add(d);
          lanSau = f;
          return Timer(const Duration(days: 1), () {});
        },
      )..chay();
      await pumpEventQueue();
      expect(hen, [const Duration(seconds: 30)]);
      lanSau!();
      await pumpEventQueue();
      expect(hen.last, const Duration(minutes: 2));
      api.mang = true;
      lanSau!();
      await pumpEventQueue();
      expect(c.lanThuLai, 0);
      expect(hen, hasLength(2));
      final truoc = api.goi;
      c.chay();
      await pumpEventQueue();
      expect(api.goi, truoc, reason: 'phiên còn hạn -> không gọi mạng');
    },
  );
}
