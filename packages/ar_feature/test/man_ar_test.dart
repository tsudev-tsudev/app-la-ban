import 'package:ar_feature/ar_feature.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_kit/test_kit.dart';

/// Camera giả: lần lượt trả lỗi trong [loi] rồi mở được.
final class CameraGia implements CameraAr {
  new([List<LoiCamera>? loi]) : loi = loi ?? [];

  final List<LoiCamera> loi;
  int soLanMo = 0;
  int soLanDong = 0;
  bool daMoCaiDat = false;

  @override
  Future<XemTruocCamera> mo() async {
    soLanMo++;
    if (loi.isNotEmpty) throw NgoaiLeCamera(loi.removeAt(0));
    return (
      texture: 1,
      rong: 720.0,
      cao: 960.0,
      truongNhin: (ngang: 49.0, doc: 63.0),
      xoay: 1,
    );
  }

  @override
  Future<void> dong() async => soLanDong++;

  @override
  Future<void> moCaiDat() async => daMoCaiDat = true;
}

const DocAr _doc = (
  camera: (phuongVi: 20, ngoc: 2, lan: 0),
  dungDung: true,
  canHieuChuan: false,
);

const _diem = <DiemAr>[
  (id: 'a', ten: 'Cột cờ Hà Nội', phuongVi: 30, khoangCachM: 456, ngoc: 0),
  (id: 'b', ten: 'Hồ Tây', phuongVi: 300, khoangCachM: 3420, ngoc: 0),
];

Widget arThu({
  required OMaTran o,
  CameraAr? camera,
  DocAr? doc = _doc,
  List<DiemAr> diem = _diem,
  bool coViTri = true,
}) => ProviderScope(
  overrides: [
    cameraArProvider.overrideWithValue(camera ?? CameraGia()),
    docArProvider.overrideWithValue(doc),
    diemArProvider.overrideWithValue(diem),
    coViTriArProvider.overrideWithValue(coViTri),
  ],
  child: khungThu(const ManAr(), o: o),
);

void main() {
  setUpAll(napFontThat);

  testWidgets('ma trận: không tràn', (tester) async {
    await kiemMaTran(tester, (o) => arThu(o: o));
  });

  testWidgets('golden', (tester) async {
    await chupGolden(tester, 'man_ar', (o) => arThu(o: o));
  });

  testWidgets('golden nhắc: nằm ngang, cần hiệu chuẩn, chưa có vị trí', (
    tester,
  ) async {
    await chupGolden(
      tester,
      'man_ar_nhac',
      (o) => arThu(
        o: o,
        doc: (
          camera: (phuongVi: 350, ngoc: -20, lan: 12),
          dungDung: false,
          canHieuChuan: true,
        ),
        diem: const [],
        coViTri: false,
      ),
      dsO: [oChup.first],
    );
  });

  testWidgets('điểm trong khung có nhãn, điểm ngoài khung ở mép', (
    tester,
  ) async {
    await tester.pumpWidget(arThu(o: oChup.first));
    await tester.pumpAndSettle();
    expect(find.text('Cột cờ Hà Nội'), findsOneWidget);
    expect(find.text('460 m'), findsOneWidget);
    expect(find.text('Hồ Tây · 3,4 km'), findsOneWidget);
    expect(find.text('20°'), findsOneWidget);
  });

  testWidgets('từ chối quyền -> giải thích + nút; cho phép -> mở camera', (
    tester,
  ) async {
    final cam = CameraGia([LoiCamera.tuChoi]);
    await tester.pumpWidget(arThu(o: oChup.first, camera: cam));
    await tester.pumpAndSettle();
    expect(find.text('Cho phép camera'), findsOneWidget);
    await tester.tap(find.text('Cho phép camera'));
    await tester.pumpAndSettle();
    expect(cam.soLanMo, 2);
    expect(find.text('Cho phép camera'), findsNothing);
    expect(find.byType(Texture), findsOneWidget);
  });

  testWidgets('từ chối hẳn -> mở Cài đặt', (tester) async {
    final cam = CameraGia([LoiCamera.tuChoiHan]);
    await tester.pumpWidget(arThu(o: oChup.first, camera: cam));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở Cài đặt'));
    expect(cam.daMoCaiDat, isTrue);
  });

  testWidgets('rời màn -> đóng camera', (tester) async {
    final cam = CameraGia();
    await tester.pumpWidget(arThu(o: oChup.first, camera: cam));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(cam.soLanDong, 1);
  });
}
