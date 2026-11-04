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

  /// Yêu cầu đã ký: (phương thức, đường dẫn, thân, header).
  final ky = <(String, String, List<int>?, Map<String, String>)>[];
  PhanHoiKy? Function(String duong, Map<String, String> tieuDe)? xuLyKy;

  @override
  Future<PhanHoiKy> goiTho(
    String phuongThuc,
    String duongDan, {
    List<int>? than,
    Map<String, String> tieuDe = const {},
  }) async {
    if (matMang) throw const LoiKetNoi('SocketException');
    ky.add((phuongThuc, duongDan, than, tieuDe));
    final body = than == null
        ? const <String, Object?>{}
        : jsonDecode(utf8.decode(than)) as Map<String, Object?>;
    goi.add((duongDan, body, tieuDe['authorization']?.substring(7)));
    await Future<void>.delayed(Duration.zero);
    final rieng = xuLyKy?.call(duongDan, tieuDe);
    if (rieng != null) return rieng;
    final r = macDinh(Uri.parse(duongDan).path, body);
    return (status: r.status, duLieu: r.duLieu, gioMayChu: null);
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
      '/v1/status' => (
        status: 200,
        duLieu: {
          'trangThai': 'banned',
          'mucTin': 'device',
          'ref': 'REF-00ABC-DEFGH',
          'banMoi': {'phienBan': '0.1.0-beta.6', 'maPhienBan': 6},
        },
      ),
      '/v1/events' => (
        status: 202,
        duLieu: {'nhan': (body['events']! as List<Object?>).length, 'trung': 0},
      ),
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

  KetQuaNative moiTruong = const KetQuaNative(coNative: true);
  bool? che;

  @override
  Future<KetQuaNative> kiemTraMoiTruong() async => moiTruong;

  @override
  Future<void> cheManHinh({required bool bat}) async => che = bat;
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
    test(
      'chuỗi ký request: vector chung với workers/api/test/kenh.test.ts',
      () {
        const than = '{"a":1}';
        final bam = bamThan(utf8.encode(than));
        expect(
          bam,
          '015abd7f5cc57a2dd94b7590f04ad8084273905ee33ec5cebeae62276a97f862',
        );
        expect(
          chuoiYeuCau(
            phuongThuc: 'post',
            duongDan: '/v1/events',
            query: 'z=2&a=b c&a=%C3%A1&m=x+y&k=!*',
            bamThan: bam,
            ts: 1761800000000,
            nonce: 'AAAAAAAAAAAAAAAAAAAAAA',
          ),
          'POST\n/v1/events\na=b%20c&a=%C3%A1&k=%21%2A&m=x%20y&z=2\n'
          '015abd7f5cc57a2dd94b7590f04ad8084273905ee33ec5cebeae62276a97f862\n'
          '1761800000000\nAAAAAAAAAAAAAAAAAAAAAA',
        );
        expect(
          bamThan(const []),
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        );
        expect(querySapXep(''), '');
        expect(querySapXep('b=2&&a=3&a=1&c'), 'a=1&a=3&b=2&c=');
        expect(maHoaRfc3986("a b!'()*~._-"), 'a%20b%21%27%28%29%2A~._-');
      },
    );

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
    test(
      'lịch thử lại: 30 s -> 2 phút -> 10 phút -> thôi; bị cấm không thử',
      () {
        expect(LichThuLai.cho(0, 'dinhDanh.mang'), const Duration(seconds: 30));
        expect(LichThuLai.cho(2, 'dinhDanh.mang'), const Duration(minutes: 10));
        expect(LichThuLai.cho(3, 'dinhDanh.mang'), isNull);
        expect(LichThuLai.cho(0, 'dinhDanh.biCam'), isNull);
      },
    );
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
      // R3b: mở lại app sau khi token hết hạn -> vẫn ra trạng thái banned
      // (server quyết) để app hiện màn khoá, không chỉ là lỗi mạng.
      final t = (await d.tinhTrang() as Ok<TinhTrangThietBi>).value;
      expect(t.trangThai, TrangThaiThietBi.banned);
      expect(t.ref, isNull);
    });

    test('đăng ký bị từ chối vì cấm -> Failure biCam (dừng thử lại)', () async {
      api.xuLy = (duong, body) => duong == '/v1/device/register'
          ? (status: 403, duLieu: {'code': 'thiet-bi-bi-cam'})
          : api.macDinh(duong, body);
      final d = dv();
      expect(((await d.damBaoPhien()) as Err).failure.code, 'dinhDanh.biCam');
      expect(((await d.tinhTrang()) as Err).failure.code, 'dinhDanh.biCam');
    });

    test('mã REF theo công thức Worker; id sai dạng -> null', () {
      // Cùng ví dụ với test Worker: 10 ký tự cuối, tách 5 - 5.
      expect(maRefThietBi('01M6ECZHZF0000000000ABCDEF'), 'REF-0000A-BCDEF');
      expect(maRefThietBi('TB1'), isNull);
      expect(maRefThietBi('01m6eczhzf0000000000abcdef'), isNull);
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
      final daKy = nt.daKy;
      expect(
        daKy[daKy.length - 2],
        chuoiXacThuc(body['thachThuc']! as String, 'TB1'),
      );
      expect(daKy.last, startsWith('POST\n/v1/device/attest\n\n'));
      expect(dv().phien?.mucTin, MucTin.strong);
    });

    group('yêu cầu ký (SEC-NET)', () {
      test('header đủ, chữ ký trên đúng chuỗi chuẩn của byte gửi đi', () async {
        bayGio = 1761800000000;
        final d = dv();
        final kq = await d.goiKy(
          'POST',
          '/v1/events?b=2&a=1',
          body: {
            'events': ['á'],
          },
        );
        expect((kq as Ok<PhanHoiKy>).value.status, 202);
        final (pt, duong, than, td) = api.ky.single;
        expect((pt, duong), ('POST', '/v1/events?b=2&a=1'));
        expect(utf8.decode(than!), '{"events":["á"]}');
        expect(td['authorization'], 'Bearer at2');
        expect(td['x-device-id'], 'TB1');
        expect(td['x-timestamp'], '1761800000000');
        expect(td['x-nonce'], matches(RegExp(r'^[A-Za-z0-9_-]{32}$')));
        expect(td['x-signature'], b64url(List.filled(70, 1)));
        // Dạng pubspec `ten+build` - Worker docPhienBanApp chỉ nhận dạng này.
        expect(td['x-app-version'], '0.1.0+5');
        expect(
          nt.daKy.last,
          chuoiYeuCau(
            phuongThuc: 'POST',
            duongDan: '/v1/events',
            query: 'a=1&b=2',
            bamThan: bamThan(than),
            ts: 1761800000000,
            nonce: td['x-nonce']!,
          ),
        );
      });

      test('lệch giờ -> hiệu chỉnh theo giờ server, ký lại một lần', () async {
        bayGio = 1000000;
        final d = dv();
        var lan = 0;
        api.xuLyKy = (_, td) => lan++ == 0
            ? (status: 401, duLieu: {'code': 'lech-gio'}, gioMayChu: 1090000)
            : null;
        final kq = await d.goiKy('GET', '/v1/status');
        expect((kq as Ok<PhanHoiKy>).value.status, 200);
        expect(api.ky.map((k) => k.$4['x-timestamp']), ['1000000', '1090000']);
        expect(api.ky.map((k) => k.$4['x-nonce']).toSet(), hasLength(2));
        // Lần sau dùng luôn độ lệch đã học.
        await d.goiKy('GET', '/v1/status');
        expect(api.ky.last.$4['x-timestamp'], '1090000');
      });

      test(
        'token bị từ chối -> làm mới rồi gửi lại; lần 2 lỗi thì trả',
        () async {
          final d = dv();
          await d.damBaoPhien();
          api.xuLyKy = (_, td) => td['authorization'] == 'Bearer at2'
              ? (status: 401, duLieu: {'code': 'token-sai'}, gioMayChu: null)
              : null;
          final kq = await d.goiKy('GET', '/v1/status');
          expect((kq as Ok<PhanHoiKy>).value.status, 200);
          expect(api.goi.map((g) => g.$1), contains('/v1/session/refresh'));
          expect(api.ky.last.$4['authorization'], isNot('Bearer at2'));
          api.xuLyKy = (_, _) =>
              (status: 401, duLieu: {'code': 'nonce'}, gioMayChu: null);
          expect(
            ((await d.goiKy(
              'GET',
              '/v1/status',
            )) as Ok<PhanHoiKy>).value.status,
            401,
          );
        },
      );

      test(
        'S11: pt nằm trong chuỗi ký; cheDoPhatTrien đọc từ phản hồi',
        () async {
          final d = dv();
          await d.tinhTrang(phatTrien: const TrangThaiPhatTrien(adbWifi: true));
          expect(nt.daKy.last, contains('\n/v1/status\npt=1\n'));
          await d.tinhTrang(phatTrien: TrangThaiPhatTrien.sach);
          expect(nt.daKy.last, contains('\n/v1/status\npt=0\n'));
          final t = TinhTrangThietBi.tuJson({
            'trangThai': 'clean',
            'mucTin': 'device',
            'cheDoPhatTrien': true,
          })!;
          expect(t.cheDoPhatTrien, isTrue);
          expect(t.voiPhatTrien(chan: false).cheDoPhatTrien, isFalse);
          expect(
            TinhTrangThietBi.tuJson({'trangThai': 'clean'})!.cheDoPhatTrien,
            isFalse,
          );
        },
      );

      test('M1a: quyenLoi nguyên văn, giữ qua voiPhatTrien', () {
        final t = TinhTrangThietBi.tuJson({
          'trangThai': 'clean',
          'quyenLoi': {'pro': true, 'khongQuangCao': true, 'hetHan': null},
        })!;
        expect(t.quyenLoi?['pro'], isTrue);
        expect(t.voiPhatTrien(chan: true).quyenLoi, same(t.quyenLoi));
        expect(
          TinhTrangThietBi.tuJson({'trangThai': 'clean', 'quyenLoi': 1})!
              .quyenLoi,
          isNull,
        );
      });

      test('tình trạng + bản mới; gửi lô sự kiện', () async {
        final d = dv();
        final t = (await d.tinhTrang() as Ok<TinhTrangThietBi>).value;
        expect(t.trangThai, TrangThaiThietBi.banned);
        expect(t.ref, 'REF-00ABC-DEFGH');
        expect(t.banMoi, (phienBan: '0.1.0-beta.6', maPhienBan: 6));
        final n = await d.guiSuKien([
          {'type': 'A'},
          {'type': 'B'},
        ]);
        expect((n as Ok<int>).value, 2);
        api.xuLyKy = (_, _) => (status: 500, duLieu: null, gioMayChu: null);
        expect(
          ((await d.tinhTrang()) as Err).failure.code,
          'dinhDanh.trangThai',
        );
        expect(
          ((await d.guiSuKien(const [])) as Err).failure.code,
          'dinhDanh.suKien',
        );
      });

      test('mất mạng -> Failure dinhDanh.mang', () async {
        final d = dv();
        await d.damBaoPhien();
        api.matMang = true;
        expect(
          ((await d.goiKy('GET', '/v1/status')) as Err).failure.code,
          'dinhDanh.mang',
        );
      });

      test('TinhTrangThietBi.tuJson: thiếu / lạ', () {
        expect(TinhTrangThietBi.tuJson(null), isNull);
        expect(TinhTrangThietBi.tuJson({'trangThai': 1}), isNull);
        final t = TinhTrangThietBi.tuJson({
          'trangThai': 'la',
          'banMoi': {'phienBan': 1},
        })!;
        expect(
          (t.trangThai, t.mucTin, t.ref, t.banMoi),
          (TrangThaiThietBi.clean, MucTin.unverified, null, null),
        );
      });
    });

    test('thách thức lỗi -> Failure có mã ổn định', () async {
      api.xuLy = (_, _) => (status: 429, duLieu: {'code': 'qua-nhieu-yeu-cau'});
      final kq = await dv().damBaoPhien();
      expect((kq as Err).failure.code, 'dinhDanh.thachThuc');
    });
  });
}
