import 'package:compass_feature/compass_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';
import 'package:test_kit/test_kit.dart';

/// Máy rẻ: không từ kế, có game rotation vector (con quay + gia tốc).
const KhaNangCamBien khongTuKe = (
  xoayVector: false,
  xoayGame: true,
  tu: false,
  giaToc: true,
  conQuay: true,
  apSuat: false,
);

/// Game rotation vector chỉ phương vị tương đối [pv] (máy nằm ngửa).
MauCamBien xoayGame(double pv, int tNs) {
  final q = Quat.quanhTruc(const Vec3(0, 0, 1), -pv * 3.141592653589793 / 180);
  return MauCamBien(LoaiMau.xoayGame, tNs, x: q.x, y: q.y, z: q.z, w: q.w);
}

/// Hà Nội 04/11/2026 9:00 giờ địa phương: Mặt Trời ~ 140°, cao ~ 40°.
final _luc = DateTime.utc(2026, 11, 4, 2);

List<Override> ghiDe({
  KhaNangCamBien kn = khongTuKe,
  List<MauCamBien> tuongDoi = const [],
  int soNhan = 8,
  bool daNeo = false,
}) => [
  if (daNeo) neoHuongProvider.overrideWith(_NeoSan.new),
  huongProvider.overrideWith(
    (_) => Stream.error(const NgoaiLeCamBien(LoiCamBien.khongCoLaBan)),
  ),
  nguonCamBienProvider.overrideWithValue(
    NguonCamBienGhiSan([
      for (final m in tuongDoi) maHoaLo([m]),
    ], khaNang: kn),
  ),
  dichVuHuongProvider.overrideWith(
    (ref) => DichVuHuong(ref.watch(nguonCamBienProvider), dungIsolate: false),
  ),
  viTriProvider.overrideWith(_ViTriHaNoi.new),
  dongHoProvider.overrideWithValue(() => _luc),
  soNhanProvider.overrideWithValue(soNhan),
];

class _ViTriHaNoi extends ViTriNotifier {
  @override
  ViTriDiaLy? build() =>
      const ViTriDiaLy(viDo: 21.0285, kinhDo: 105.8542, doCaoM: 15);
}

Widget dung(OMaTran o, List<Override> gd, {Widget man = const ManLaBan()}) =>
    ProviderScope(
      overrides: gd,
      child: khungThu(man, o: o),
    );

void main() {
  setUpAll(napFontThat);

  testWidgets('không từ kế, chưa neo: giải thích + nút nguồn, không mặt số', (
    tester,
  ) async {
    await tester.pumpWidget(dung(oChup.first, ghiDe()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Máy không có la bàn từ'), findsOneWidget);
    expect(find.byType(MatLaBan), findsNothing);
    final matTroi = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Theo bóng Mặt Trời'),
    );
    expect(matTroi.onPressed, isNotNull, reason: 'Mặt Trời đang trên cao');
  });

  testWidgets('neo theo bóng Mặt Trời rồi xoay máy: con quay giữ hướng', (
    tester,
  ) async {
    await tester.pumpWidget(
      dung(
        oChup.first,
        ghiDe(tuongDoi: [xoayGame(0, 1)]),
      ),
    );
    // Dò cảm biến xong -> luồng con quay mới bắt đầu ở khung kế.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    final c = ProviderScope.containerOf(
      tester.element(find.byType(ManKhongTuKe)),
    );
    final mt = viTriMatTroi(_luc, 21.0285, 105.8542);
    c.read(neoHuongProvider.notifier).neo((
      phuongVi: chuanHoaDo(mt.phuongVi + 180),
      bacThuc: true,
      nguon: NguonChiHuong.matTroi,
      saiSoDo: 5,
      theoConQuay: false,
    ));
    await tester.pump(const Duration(milliseconds: 50));
    final u = c.read(huongDaNguonProvider)!;
    expect(u.nguon, NguonChiHuong.matTroi);
    expect(u.theoConQuay, isTrue);
    expect(find.byType(MatLaBan), findsOneWidget);
    expect(find.textContaining('Mặt Trời + con quay'), findsOneWidget);
  });

  testWidgets('tự đặt hướng qua hộp thoại', (tester) async {
    await tester.pumpWidget(dung(oChup.first, ghiDe()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(FilledButton, 'Tự đặt hướng'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Neo hướng'));
    await tester.pumpAndSettle();
    expect(find.byType(MatLaBan), findsOneWidget);
    expect(find.textContaining('Nguồn: Tự đặt'), findsOneWidget);
  });

  testWidgets('máy không con quay: neo tĩnh + nhắc giữ tư thế', (tester) async {
    await tester.pumpWidget(
      dung(
        oChup.first,
        ghiDe(
          kn: (
            xoayVector: false,
            xoayGame: false,
            tu: false,
            giaToc: true,
            conQuay: false,
            apSuat: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    ProviderScope.containerOf(tester.element(find.byType(ManKhongTuKe)))
        .read(neoHuongProvider.notifier)
        .neoThuCong(90);
    await tester.pump();
    expect(find.textContaining('Máy không có con quay'), findsOneWidget);
    expect(find.textContaining('Nguồn: Tự đặt ·'), findsOneWidget);
  });

  testWidgets('ma trận: màn không từ kế (đã neo) + Thiết bị: không tràn', (
    tester,
  ) async {
    await kiemMaTran(tester, (o) => dung(o, ghiDe(daNeo: true)));
    await kiemMaTran(
      tester,
      (o) => dung(o, ghiDe(soNhan: 4), man: const ManThietBi()),
    );
  });

  testWidgets('trợ năng: màn không từ kế, màn Thiết bị', (tester) async {
    await kiemTroNang(tester, (o) => dung(o, ghiDe()));
    await kiemTroNang(tester, (o) => dung(o, ghiDe(), man: const ManThietBi()));
  });

  testWidgets('golden: không từ kế (chưa neo / đã neo), Thiết bị', (
    tester,
  ) async {
    await chupGolden(
      tester,
      'khong_tu_ke',
      (o) => dung(o, ghiDe()),
      dsO: [oChup.first],
    );
    await chupGolden(
      tester,
      'khong_tu_ke_da_neo',
      (o) => dung(o, ghiDe(daNeo: true)),
    );
    await chupGolden(
      tester,
      'thiet_bi',
      (o) => dung(o, ghiDe(soNhan: 4), man: const ManThietBi()),
      dsO: [oChup.first, oChup.last],
    );
  });
}

/// Đã neo thủ công 250° (neo tĩnh - dùng cho golden / ma trận).
class _NeoSan extends NeoHuongNotifier {
  @override
  NeoHuong? build() => NeoHuong.tu(
    (
      phuongVi: 250,
      bacThuc: true,
      nguon: NguonChiHuong.thuCong,
      saiSoDo: 10,
      theoConQuay: false,
    ),
    phuongViTuongDoi: 0,
    tNs: 0,
    tinh: true,
  );
}
