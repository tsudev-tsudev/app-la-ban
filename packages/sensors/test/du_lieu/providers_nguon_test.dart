import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

ChuyenDongGps gps(int giay, {double tocDo = 1.5}) => (
  viDo: 21,
  kinhDo: 105 + giay * tocDo / 103900,
  tocDo: tocDo,
  huongDi: 90,
  saiSoTocDo: null,
  saiSoHuongDi: 6,
  luc: DateTime.utc(2026, 11, 4).add(Duration(seconds: giay)),
);

void main() {
  test('máy không từ kế: đi bộ -> hướng GPS, tự neo con quay; dừng lại -> '
      'con quay giữ hướng theo neo GPS', () async {
    final tuongDoi = StreamController<({double phuongVi, int tNs})>();
    addTearDown(tuongDoi.close);
    final c = ProviderContainer(
      overrides: [
        huongProvider.overrideWith(
          (_) => Stream.error(const NgoaiLeCamBien(LoiCamBien.khongCoLaBan)),
        ),
        khaNangCamBienProvider.overrideWith(
          (_) async => (
            xoayVector: false,
            xoayGame: true,
            tu: false,
            giaToc: true,
            conQuay: true,
            apSuat: false,
          ),
        ),
        huongTuongDoiProvider.overrideWith((_) => tuongDoi.stream),
      ],
    );
    addTearDown(c.dispose);
    final nghe = c.listen(huongDaNguonProvider, (_, _) {});
    addTearDown(nghe.close);
    await c.read(khaNangCamBienProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(coTuKeProvider), isFalse);
    expect(c.read(huongDaNguonProvider), isNull);

    tuongDoi.add((phuongVi: 10, tNs: 0));
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 12; i++) {
      c.read(chuyenDongGpsProvider.notifier).nap(gps(i));
      c.read(huongDaNguonProvider);
    }
    final dangDi = c.read(huongDaNguonProvider)!;
    expect(dangDi.nguon, NguonChiHuong.gps);
    expect(dangDi.phuongVi, 90);
    expect(c.read(neoHuongProvider)?.goc.nguon, NguonChiHuong.gps);

    // Dừng lại, xoay máy 30° sang phải: con quay giữ hướng = 90 + 30.
    c.read(chuyenDongGpsProvider.notifier).nap(gps(13, tocDo: 0));
    tuongDoi.add((phuongVi: 40, tNs: 60000000000));
    await Future<void>.delayed(Duration.zero);
    final dung = c.read(huongDaNguonProvider)!;
    expect(dung.nguon, NguonChiHuong.gps);
    expect(dung.theoConQuay, isTrue);
    expect(dung.phuongVi, closeTo(120, 1e-9));
    expect(dung.saiSoDo, closeTo(7, 1e-9)); // 6° + trôi 1°/phút
  });

  test('máy có từ kế: dùng từ kế, cộng độ lệch WMM thành bắc thực', () async {
    const h = HuongDoc(
      phuongVi: 100,
      phuongViTho: 100,
      doc: 0,
      lan: 0,
      theoCamera: false,
      muc: MucTinCay.cao,
      nhieuTu: false,
      canHieuChuan: false,
      cuongDoTu: 45,
      nguon: NguonHuong.madgwick,
      dungYen: true,
      tNs: 0,
    );
    final c = ProviderContainer(
      overrides: [
        huongProvider.overrideWith((_) => Stream.value(h)),
        viTriProvider.overrideWith(_HaNoi.new),
        dongHoProvider.overrideWithValue(() => DateTime.utc(2026, 11, 4)),
      ],
    );
    addTearDown(c.dispose);
    final nghe = c.listen(huongDaNguonProvider, (_, _) {});
    addTearDown(nghe.close);
    await c.read(huongProvider.future);
    final u = c.read(huongDaNguonProvider)!;
    expect(u.nguon, NguonChiHuong.tuKe);
    expect(u.bacThuc, isTrue);
    expect(u.phuongVi, closeTo(100 + c.read(tuTruongProvider)!.doLech, 1e-9));
    expect(u.saiSoDo, 3);
  });

  test(
    'chế độ nhẹ: máy 4 nhân hoặc không con quay; không dò được -> tắt',
    () async {
      Future<bool> nhe(KhaNangCamBien k, int soNhan) async {
        final c = ProviderContainer(
          overrides: [
            khaNangCamBienProvider.overrideWith((_) async => k),
            soNhanProvider.overrideWithValue(soNhan),
          ],
        );
        addTearDown(c.dispose);
        await c.read(khaNangCamBienProvider.future);
        final bat = c.read(cheDoNheProvider);
        return bat;
      }

      const du = (
        xoayVector: true,
        xoayGame: true,
        tu: true,
        giaToc: true,
        conQuay: true,
        apSuat: true,
      );
      const rong = (
        xoayVector: false,
        xoayGame: false,
        tu: false,
        giaToc: false,
        conQuay: false,
        apSuat: false,
      );
      expect(await nhe(du, 8), isFalse);
      expect(await nhe(du, 4), isTrue);
      expect(await nhe(rong, 2), isFalse);
    },
  );
}

class _HaNoi extends ViTriNotifier {
  @override
  ViTriDiaLy? build() => const ViTriDiaLy(viDo: 21.03, kinhDo: 105.85);
}
