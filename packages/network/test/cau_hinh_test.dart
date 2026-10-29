import 'dart:convert';
import 'dart:io';

import 'package:network/network.dart';
import 'package:test/test.dart';

/// Gói mẫu ký bằng khoá THỬ (khoá bí mật đã bỏ; chỉ giữ khoá công khai).
final Map<String, Object?> mau = jsonDecode(
  File('test/du_lieu/goi_mau.json').readAsStringSync(),
) as Map<String, Object?>;
final khoa = {'thu-1': mau['khoa']! as String};
final bayGio = mau['bayGio']! as int;
String goi(String ten) => jsonEncode(mau[ten]);

final class ApiGia implements ApiClient {
  PhanHoiApi Function() tra = () => const PhanHoiApi(404, null);
  int dem = 0;

  @override
  Future<PhanHoiApi> goi(
    String phuongThuc,
    String duongDan, {
    List<int>? than,
    Map<String, String> tieuDe = const {},
  }) async {
    dem++;
    expect((phuongThuc, duongDan), ('GET', '/v1/config'));
    return tra();
  }

  @override
  Future<PhanHoiApi> get(String duongDan, {String? bearer}) =>
      throw UnimplementedError();

  @override
  Future<PhanHoiApi> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  }) => throw UnimplementedError();
}

final class KhoNho implements KhoGoiCauHinh {
  String? giaTri;

  @override
  String? doc() => giaTri;

  @override
  Future<void> ghi(String goi) async => giaTri = goi;
}

void main() {
  group('docGoiCauHinh', () {
    test('gói hợp lệ -> nội dung đầy đủ', () {
      final kq = docGoiCauHinh(goi('hopLe'), khoa: khoa, bayGio: bayGio);
      final ch = (kq as GoiHopLe).cauHinh;
      expect(ch.toiThieu, 3);
      expect(ch.khuyenNghi, 5);
      expect(ch.tat, {'ar'});
      expect(ch.pin, [for (final g in gocTinCay) g.pin]);
      expect(ch.gocHieuLuc, hasLength(gocTinCay.length));
      expect(ch.het, greaterThan(bayGio));
    });

    test('sai khoá / kid lạ / hình dạng / hết hạn / cũ hơn', () {
      String? lyDo(String raw, {int? giu, int? luc}) => switch (docGoiCauHinh(
        raw,
        khoa: khoa,
        bayGio: luc ?? bayGio,
        phatHanhDangGiu: giu,
      )) {
        GoiBiTuChoi(:final lyDo) => lyDo,
        GoiHopLe() => null,
      };
      expect(lyDo(goi('khoaKhac')), 'chu-ky');
      expect(lyDo(goi('hopLe').replaceFirst('thu-1', 'thu-2')), 'kid');
      expect(lyDo('{'), 'dang');
      expect(lyDo('[]'), 'dang');
      expect(
        lyDo(jsonEncode({'kid': 'thu-1', 'duLieu': 'a+b', 'chuKy': 'x'})),
        'dang',
      );
      final hl = (docGoiCauHinh(
        goi('hopLe'),
        khoa: khoa,
        bayGio: bayGio,
      ) as GoiHopLe).cauHinh;
      expect(lyDo(goi('hopLe'), luc: hl.het), 'het-han');
      expect(lyDo(goi('hopLe'), giu: hl.phatHanh + 1), 'cu-hon');
      expect(lyDo(goi('hopLe'), giu: hl.phatHanh), isNull);
      // Ký đúng nhưng chỉ 1 pin: app không nhận (SEC-NET >= 2).
      expect(lyDo(goi('motPin')), 'noi-dung');
    });

    test('sửa duLieu (đổi build tối thiểu) -> chữ ký sai', () {
      final g = Map<String, Object?>.of(mau['hopLe']! as Map<String, Object?>);
      final nd = utf8.decode(
        base64Url.decode(base64Url.normalize(g['duLieu']! as String)),
      );
      g['duLieu'] = base64Url
          .encode(utf8.encode(nd.replaceFirst('"toiThieu":3', '"toiThieu":1')))
          .replaceAll('=', '');
      expect(
        docGoiCauHinh(jsonEncode(g), khoa: khoa, bayGio: bayGio),
        isA<GoiBiTuChoi>(),
      );
    });

    test('xoay pin: chỉ còn 2 CA; CA thêm qua gocThem', () {
      final xoay = (docGoiCauHinh(
        goi('xoayPin'),
        khoa: khoa,
        bayGio: bayGio,
      ) as GoiHopLe).cauHinh;
      expect(xoay.gocHieuLuc, hasLength(2));
      expect(xoay.gocHieuLuc.map(pinCuaPem), xoay.pin);
      final them = (docGoiCauHinh(
        goi('gocThem'),
        khoa: khoa,
        bayGio: bayGio,
      ) as GoiHopLe).cauHinh;
      expect(them.gocThem, hasLength(1));
      expect(pinCuaPem(them.gocThem.single), them.pin.last);
    });
  });

  group('DichVuCauHinh', () {
    late ApiGia api;
    late KhoNho kho;
    var luc = bayGio;
    final doi = <CauHinhTuXa?>[];

    DichVuCauHinh dv() => DichVuCauHinh(
      api: api,
      kho: kho,
      khoa: khoa,
      dongHo: () => luc,
      khiDoi: doi.add,
    );

    PhanHoiApi Function() tra(String ten) =>
        () => PhanHoiApi(200, mau[ten]! as Map<String, Object?>);

    setUp(() {
      api = ApiGia();
      kho = KhoNho();
      luc = bayGio;
      doi.clear();
    });

    test(
      'chưa có gói -> mặc định đóng gói; 404 / mạng lỗi giữ nguyên',
      () async {
        final d = dv();
        expect(d.hienTai, isNull);
        expect(d.gocTinCay, gocMacDinh);
        expect(await d.lamMoi(), 'khong-co');
        api.tra = () => throw const LoiMang('tls');
        expect(await d.lamMoi(), 'mang');
        api.tra = () => const PhanHoiApi(503, null);
        expect(await d.lamMoi(), 'http-503');
        expect(doi, isEmpty);
      },
    );

    test(
      'nhận gói -> lưu, báo đổi; mở lại đọc từ kho; gói cũ bị từ chối',
      () async {
        final d = dv();
        api.tra = tra('moiHon');
        expect(await d.lamMoi(), 'ok');
        expect(d.hienTai?.toiThieu, 4);
        expect(doi, hasLength(1));
        expect(await d.lamMoi(), 'ok');
        expect(doi, hasLength(1), reason: 'cùng gói -> không báo lại');
        final moLai = dv();
        expect(moLai.hienTai?.phatHanh, d.hienTai?.phatHanh);
        api.tra = tra('hopLe');
        expect(await moLai.lamMoi(), 'cu-hon');
        expect(moLai.hienTai?.toiThieu, 4);
      },
    );

    test('xoay pin -> gocTinCay đổi; hết hạn -> về mặc định', () async {
      final d = dv();
      api.tra = tra('xoayPin');
      expect(await d.lamMoi(), 'ok');
      expect(d.gocTinCay, hasLength(2));
      luc = d.hienTai!.het;
      expect(d.hienTai, isNull);
      expect(d.gocTinCay, gocMacDinh);
    });

    test('gói sai chữ ký trong kho (bị sửa trên máy) -> bỏ qua', () async {
      kho.giaTri = goi('khoaKhac');
      expect(dv().hienTai, isNull);
      api.tra = tra('khoaKhac');
      expect(await dv().lamMoi(), 'chu-ky');
      expect(kho.giaTri, goi('khoaKhac'));
    });
  });

  test('khoá công khai app-1 là 32 byte', () {
    expect(
      base64Url.decode(base64Url.normalize(khoaCauHinhApp['app-1']!)),
      hasLength(32),
    );
  });
}
