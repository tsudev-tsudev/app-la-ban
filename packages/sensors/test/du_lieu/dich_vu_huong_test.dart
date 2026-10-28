import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

import '../mo_phong.dart';

/// Chia chuỗi mẫu thành lô 16 ms giống plugin Android.
List<Float64List> thanhLo(List<MauCamBien> ds, {int moiLo = 6}) => [
  for (var i = 0; i < ds.length; i += moiLo)
    maHoaLo(ds.sublist(i, i + moiLo > ds.length ? ds.length : i + moiLo)),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final iso in [false, true]) {
    test('phát hướng hợp nhất (isolate: $iso)', () async {
      final nguon = NguonCamBienGhiSan(
        thanhLo(moPhong((_) => tuGoc(33, 0, 0), thoiGian: 4.5)),
      );
      final ra = await DichVuHuong(nguon, dungIsolate: iso).theoDoi().toList();
      expect(ra, isNotEmpty);
      expect(saiSo(ra.last.phuongVi, 33), lessThan(1));
      // Đứng yên > 3 s -> yêu cầu nền tảng hạ xuống 20 Hz.
      expect(nguon.lichSuChuKy, [chuKyNhanhUs, chuKyChamUs]);
    });
  }

  test('máy không có la bàn -> NgoaiLeCamBien', () async {
    final nguon = NguonCamBienGhiSan(
      const [],
      khaNang: (
        xoayVector: false,
        xoayGame: false,
        tu: false,
        giaToc: true,
        conQuay: false,
        apSuat: false,
      ),
    );
    await expectLater(
      DichVuHuong(nguon).theoDoi(),
      emitsError(
        isA<NgoaiLeCamBien>().having(
          (e) => e.loi,
          'loi',
          LoiCamBien.khongCoLaBan,
        ),
      ),
    );
    expect(
      const NgoaiLeCamBien(LoiCamBien.khongCoLaBan).toString(),
      contains('khongCoLaBan'),
    );
  });

  test('huỷ nghe sớm dừng nguồn (isolate)', () async {
    final nguon = NguonCamBienGhiSan(
      thanhLo(moPhong((_) => tuGoc(0, 0, 0), thoiGian: 3)),
      khoang: const Duration(milliseconds: 2),
    );
    final sub = DichVuHuong(nguon).theoDoi().listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
  });

  test('hủy trước khi isolate kịp khởi động', () async {
    final nguon = NguonCamBienGhiSan(
      thanhLo(moPhong((_) => tuGoc(0, 0, 0), thoiGian: 1)),
    );
    final sub = DichVuHuong(nguon).theoDoi().listen((_) {});
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });

  group('NguonCamBienNenTang', () {
    const lenh = MethodChannel('la_ban/cam_bien');
    final may =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => may.setMockMethodCallHandler(lenh, null));

    test(
      'khaNang đọc map; thiếu plugin (iOS trước I1) -> toàn false',
      () async {
        may.setMockMethodCallHandler(
          lenh,
          (c) async =>
              c.method == 'khaNang' ? {'tu': true, 'giaToc': true} : null,
        );
        final k = await const NguonCamBienNenTang().khaNang();
        expect(k.tu, isTrue);
        expect(k.conQuay, isFalse);
        await const NguonCamBienNenTang().datChuKy(chuKyChamUs);
        may.setMockMethodCallHandler(lenh, null);
        final kk = await const NguonCamBienNenTang().khaNang();
        expect(kk.tu, isFalse);
      },
    );

    test('luồng lô từ EventChannel', () async {
      const ten = 'la_ban/cam_bien/su_kien';
      final lo = maHoaLo(const [MauCamBien(LoaiMau.tu, 1, y: 40)]);
      may.setMockStreamHandler(
        const EventChannel(ten),
        MockStreamHandler.inline(
          onListen: (args, sink) {
            expect((args! as Map)['chuKyUs'], chuKyNhanhUs);
            sink
              ..success(lo)
              ..endOfStream();
          },
        ),
      );
      final ds = await const NguonCamBienNenTang().lo().toList();
      expect(giaiMaLo(ds.single).single.y, 40);
    });
  });
}
