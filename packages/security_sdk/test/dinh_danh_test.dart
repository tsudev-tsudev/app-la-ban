import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';

/// API giả: ghi lại yêu cầu, trả theo kịch bản.
final class ApiGia implements ApiDinhDanh {
  final goi = <(String, Map<String, Object?>, String?)>[];
  PhanHoiDinhDanh Function(String duong, Map<String, Object?> body)? xuLy;
  bool matMang = false;
  int dem = 0;

  @override
  Future<PhanHoiDinhDanh> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  }) async {
    if (matMang) throw const LoiKetNoi('SocketException');
    goi.add((duongDan, body, bearer));
    await Future<void>.delayed(Duration.zero);
    return xuLy?.call(duongDan, body) ?? macDinh(duongDan, body);
  }

  PhanHoiDinhDanh macDinh(String duong, Map<String, Object?> body) {
    dem++;
    return switch (duong) {
      '/v1/device/challenge' => (
        status: 200,
        duLieu: {'thachThuc': 'T$dem' * 4},
      ),
      '/v1/device/register' => (
        status: 201,
        duLieu: {
          'thietBiId': 'TB1',
          'trangThai': 'clean',
          'mucTin': body['integrityToken'] == null ? 'unverified' : 'device',
          'phien': phienJson(dem),
        },
      ),
      '/v1/session/refresh' => (
        status: 200,
        duLieu: {'mucTin': 'device', 'phien': phienJson(dem)},
      ),
      '/v1/device/attest' => (status: 200, duLieu: {'mucTin': 'strong'}),
      _ => (status: 404, duLieu: null),
    };
  }

  int hetHan = 0;
  Map<String, Object?> phienJson(int n) => {
    'accessToken': 'at$n',
    'hetHan': hetHan,
    'refreshToken': 'rt$n',
  };
}

/// Kho trạng thái trên TepJson thật (như app nối).
final class KhoTep implements KhoTrangThai {
  new(this._t);

  final TepJson _t;

  @override
  Map<String, Object?> get duLieu => _t.duLieu;

  @override
  void ghiDongBo(Map<String, Object?> moi) => _t.ghiDongBo(moi);

  @override
  Future<void> ghi(Map<String, Object?> moi) => _t.ghi(moi);
}

final class NenTangGia implements NenTangThietBi {
  String? token = 'tok';
  final daKy = <String>[];

  @override
  Future<KhoaThietBi> khoaCongKhai() async =>
      (spki: Uint8List.fromList(List.filled(91, 7)), mucBaoMat: 'tee');

  @override
  Future<Uint8List> ky(Uint8List duLieu) async {
    daKy.add(utf8.decode(duLieu));
    return Uint8List.fromList(List.filled(70, 1));
  }

  @override
  Future<String?> integrity(int soDuAn, String requestHash) async =>
      token == null ? null : '$token:$soDuAn:$requestHash';

  @override
  Future<ThongTinMay> thongTin() async =>
      (model: 'SM-M325FV', heDieuHanh: '13', goi: 'com.tsudev.laban.stg');

  @override
  Future<void> xoaKhoa() async {}
}

void main() {
  late Directory thuMuc;
  late ApiGia api;
  late NenTangGia nt;
  var bayGio = 1000000;

  DichVuDinhDanh dv() => DichVuDinhDanh(
    api: api,
    nenTang: nt,
    tep: KhoTep(TepJson.mo('${thuMuc.path}/dinh_danh.json')),
    cauHinh: CauHinhDinhDanh(
      soDuAnCloud: 930761930572,
      phienBanApp: '0.1.0',
      build: 5,
      ngonNgu: () => 'vi',
    ),
    dongHo: () => bayGio,
  );

  setUp(() {
    thuMuc = Directory.systemTemp.createTempSync('dinh_danh');
    api = ApiGia()..hetHan = bayGio + 15 * 60 * 1000;
    nt = NenTangGia();
  });
  tearDown(() => thuMuc.deleteSync(recursive: true));

  group('chuỗi ký (khớp workers/api/src/thuan/ma-hoa.ts)', () {
    test('requestHash vector chéo với Node', () {
      final c = chuoiDangKy(
        't' * 43,
        '0f8fad5b-d9cb-469f-a165-70867728950e',
        'k' * 100,
      );
      expect(requestHash(c), 'VlGAD6lZbch8ocrqcsQJ612meBW6vOp-XY8-_cwi70k');
      expect(chuoiXacThuc('a', 'b'), 'la-ban/v1/xac-thuc\na\nb');
      expect(chuoiLamMoi('r', 5, 'n'), 'la-ban/v1/lam-moi\nr\n5\nn');
    });
    test('UUID v4 + nonce đúng mẫu server', () {
      final r = Random(1);
      for (var i = 0; i < 50; i++) {
        expect(
          uuidV4(r),
          matches(
            RegExp(
              '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
              r'[0-9a-f]{12}$',
            ),
          ),
        );
        expect(nonceNgauNhien(r), matches(RegExp(r'^[A-Za-z0-9_-]{32}$')));
      }
    });
  });

  group('PhienThietBi / SauLamMoi', () {
    test('JSON khứ hồi, thiếu trường -> null, mức lạ -> unverified', () {
      const p = PhienThietBi(
        thietBiId: 'X',
        accessToken: 'a',
        hetHan: 10,
        refreshToken: 'r',
        mucTin: MucTin.basic,
      );
      final lai = PhienThietBi.tuJson(p.toJson());
      expect(lai?.toJson(), p.toJson());
      expect(PhienThietBi.tuJson({'thietBiId': 'X'}), isNull);
      expect(MucTin.tuChuoi('la'), MucTin.unverified);
      expect(MucTin.device.duTinCay, isTrue);
      expect(MucTin.basic.duTinCay, isFalse);
    });
    test('canLamMoi trước hạn 60 s', () {
      const p = PhienThietBi(
        thietBiId: 'X',
        accessToken: 'a',
        hetHan: 100000,
        refreshToken: 'r',
        mucTin: MucTin.device,
      );
      expect(p.canLamMoi(39999), isFalse);
      expect(p.canLamMoi(40000), isTrue);
    });
    test('phản hồi lỗi làm mới', () {
      expect(SauLamMoi.tuPhanHoi(401, 'phien-thu-hoi'), SauLamMoi.dangKyLai);
      expect(SauLamMoi.tuPhanHoi(403, 'thiet-bi-bi-cam'), SauLamMoi.biCam);
      expect(SauLamMoi.tuPhanHoi(409, 'dang-xoay'), SauLamMoi.thuLaiSau);
      expect(SauLamMoi.tuPhanHoi(503, null), SauLamMoi.thuLaiSau);
    });
  });

  group('DichVuDinhDanh', () {
    test('đăng ký: ký đúng chuỗi, token gắn requestHash, lưu phiên', () async {
      final d = dv();
      final kq = await d.damBaoPhien();
      expect(kq, isA<Ok<PhienThietBi>>());
      final id = d.installationId;
      final (duong, body, _) = api.goi[1];
      expect(duong, '/v1/device/register');
      final chuoi = chuoiDangKy(
        body['thachThuc']! as String,
        id,
        body['khoaCongKhai']! as String,
      );
      expect(nt.daKy.single, chuoi);
      expect(body['integrityToken'], 'tok:930761930572:${requestHash(chuoi)}');
      expect(body['goi'], 'com.tsudev.laban.stg');
      expect(body['khoaCongKhai'], isNot(contains('=')));
      // Đọc lại từ tệp ở lần mở app sau: cùng Installation ID, có phiên.
      final lai = dv();
      expect(lai.installationId, id);
      expect(lai.phien?.accessToken, 'at2');
      expect(lai.phien?.mucTin, MucTin.device);
    });

    test('còn hạn -> không gọi mạng; sắp hết -> làm mới có chữ ký', () async {
      final d = dv();
      await d.damBaoPhien();
      final n = api.goi.length;
      await d.damBaoPhien();
      expect(api.goi.length, n);
      bayGio = api.hetHan - 30 * 1000;
      final kq = await d.damBaoPhien();
      expect((kq as Ok<PhienThietBi>).value.accessToken, 'at3');
      final (duong, body, _) = api.goi.last;
      expect(duong, '/v1/session/refresh');
      expect(
        nt.daKy.last,
        chuoiLamMoi('rt2', body['ts']! as int, body['nonce']! as String),
      );
      expect(d.phien?.refreshToken, 'rt3');
    });

    test('phiên bị thu hồi (401) -> xoá phiên + đăng ký lại', () async {
      final d = dv();
      await d.damBaoPhien();
      bayGio = api.hetHan;
      api.xuLy = (duong, body) => duong == '/v1/session/refresh'
          ? (status: 401, duLieu: {'code': 'phien-thu-hoi'})
          : api.macDinh(duong, body);
      final kq = await d.damBaoPhien();
      expect(kq, isA<Ok<PhienThietBi>>());
      expect(api.goi.map((g) => g.$1).toList().sublist(2), [
        '/v1/session/refresh',
        '/v1/device/challenge',
        '/v1/device/register',
      ]);
    });

    test('bị cấm -> Failure biCam, không đăng ký lại', () async {
      final d = dv();
      await d.damBaoPhien();
      bayGio = api.hetHan;
      api.xuLy = (_, _) => (status: 403, duLieu: {'code': 'thiet-bi-bi-cam'});
      final kq = await d.damBaoPhien();
      expect((kq as Err).failure.code, 'dinhDanh.biCam');
      expect(d.phien, isNotNull);
    });

    test(
      'mất mạng -> Failure dinhDanh.mang; máy không Play -> token null',
      () async {
        api.matMang = true;
        expect(
          ((await dv().damBaoPhien()) as Err).failure.code,
          'dinhDanh.mang',
        );
        api.matMang = false;
        nt.token = null;
        final kq = await dv().damBaoPhien();
        expect((kq as Ok<PhienThietBi>).value.mucTin, MucTin.unverified);
      },
    );

    test('gọi đồng thời chỉ đăng ký một lần', () async {
      final d = dv();
      await Future.wait([d.damBaoPhien(), d.damBaoPhien(), d.damBaoPhien()]);
      expect(api.goi.where((g) => g.$1 == '/v1/device/register'), hasLength(1));
    });

    test('xác minh lại: chuỗi xác thực + Bearer, cập nhật mức', () async {
      final d = dv();
      await d.damBaoPhien();
      final kq = await d.xacMinhLai();
      expect((kq as Ok<MucTin>).value, MucTin.strong);
      final (duong, body, bearer) = api.goi.last;
      expect(duong, '/v1/device/attest');
      expect(bearer, 'at2');
      expect(nt.daKy.last, chuoiXacThuc(body['thachThuc']! as String, 'TB1'));
      expect(dv().phien?.mucTin, MucTin.strong);
    });

    test('thách thức lỗi -> Failure có mã ổn định', () async {
      api.xuLy = (_, _) => (status: 429, duLieu: {'code': 'qua-nhieu-yeu-cau'});
      final kq = await dv().damBaoPhien();
      expect((kq as Err).failure.code, 'dinhDanh.thachThuc');
    });
  });
}
