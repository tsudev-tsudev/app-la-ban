import 'package:flutter_test/flutter_test.dart';
import 'package:map_feature/map_feature.dart';
import 'package:test_kit/test_kit.dart';

import 'thu_chung.dart';

void main() {
  setUpAll(napFontThat);

  testWidgets('trợ năng: vùng chạm, nhãn, tương phản', (tester) async {
    await kiemTroNang(tester, (o) => banDoThu(const ManVungOffline(), o: o));
  });

  testWidgets('ma trận: không tràn', (tester) async {
    await kiemMaTran(tester, (o) => banDoThu(const ManVungOffline(), o: o));
  });

  testWidgets('golden', (tester) async {
    await chupGolden(
      tester,
      'man_vung_offline',
      (o) => banDoThu(const ManVungOffline(), o: o),
    );
  });

  testWidgets('golden rỗng, chưa có vùng đang xem', (tester) async {
    await chupGolden(
      tester,
      'man_vung_offline_rong',
      (o) => banDoThu(
        const ManVungOffline(),
        o: o,
        kho: KhoVungGia(),
        coKhung: false,
      ),
      dsO: [oChup.first],
    );
  });

  testWidgets('tải vùng đang xem: z9-14, tiến độ, xong -> báo + nút bật lại', (
    tester,
  ) async {
    final kho = KhoVungGia();
    await tester.pumpWidget(
      banDoThu(const ManVungOffline(), o: oChup.first, kho: kho),
    );
    await tester.pumpAndSettle();
    final nut = find.text('Tải về');
    await tester.tap(nut.last);
    await tester.pump();
    expect(kho.daTai.single.zMin, 9);
    expect(kho.daTai.single.zMax, 14);
    expect(kho.daTai.single.ten, 'Vùng 30/10/2026 17:00');
    expect(kho.daTai.single.urlKieu, endsWith('/ban-do/kieu/sang-vi.json'));
    kho.dangTai!.add((daXong: 30, tong: 120, byte: 1000));
    await tester.pump();
    expect(find.text('Đang tải 30/120'), findsOneWidget);
    await kho.dangTai!.close();
    await tester.pumpAndSettle();
    expect(find.text('Đã tải xong vùng bản đồ.'), findsOneWidget);
  });

  testWidgets('tải lỗi -> báo lỗi, không báo xong', (tester) async {
    final kho = KhoVungGia();
    await tester.pumpWidget(
      banDoThu(const ManVungOffline(), o: oChup.first, kho: kho),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải về').first);
    await tester.pump();
    expect(kho.daTai.single.zMax, zoomTongQuan);
    kho.dangTai!.addError(Exception('mạng'));
    await kho.dangTai!.close();
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa tải xong - kiểm tra kết nối mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Đã tải xong vùng bản đồ.'), findsNothing);
  });

  testWidgets('xoá vùng có hỏi lại', (tester) async {
    final kho = KhoVungGia(List.of(vungThu));
    await tester.pumpWidget(
      banDoThu(const ManVungOffline(), o: oChup.first, kho: kho),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Vùng 30/10/2026 17:00'), 200);
    await tester.tap(find.byTooltip('Xoá vùng').last);
    await tester.pumpAndSettle();
    expect(find.text('Xoá vùng "Vùng 30/10/2026 17:00"?'), findsOneWidget);
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();
    expect(kho.daXoa, [2]);
    expect(find.text('Vùng 30/10/2026 17:00'), findsNothing);
  });
}
