import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:test_kit/test_kit.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

import 'thu_chung.dart';

final OMaTran o = (
  manHinh: manHinh12[3],
  sang: Brightness.light,
  ngonNgu: LbNgonNgu.vi,
  coChu: 1.0,
);

void main() {
  setUpAll(napFontThat);

  testWidgets('trợ năng: vùng chạm, nhãn, tương phản', (tester) async {
    await kiemTroNang(
      tester,
      (o) => dung(ManChiaSe(diem: diemThu[0]), o, ghiDe()),
    );
  });

  testWidgets('trợ năng: chi tiết điểm', (tester) async {
    await kiemTroNang(
      tester,
      (o) => dung(
        const ManChiTietDiem(id: 'a'),
        o,
        ghiDe(kho: KhoDiemBoNho(diemThu)),
      ),
    );
  });

  testWidgets('chia sẻ: ma trận không tràn + golden', (tester) async {
    await kiemMaTran(
      tester,
      (o) => dung(ManChiaSe(diem: diemThu[0]), o, ghiDe()),
    );
    await chupGolden(
      tester,
      'man_chia_se',
      (o) => dung(ManChiaSe(diem: diemThu[0]), o, ghiDe()),
    );
  });

  testWidgets('link đúng hạn đã chọn, giải mã lại đúng điểm; gửi link qua '
      'bảng chia sẻ', (tester) async {
    datManHinh(tester, o.manHinh);
    final nt = NenTangGia();
    await tester.pumpWidget(
      dung(ManChiaSe(diem: diemThu[0]), o, ghiDe(nenTang: nt)),
    );
    await tester.pumpAndSettle();
    String link() => tester
        .widget<SelectableText>(
          find.descendant(
            of: find.byKey(const ValueKey('link-chia-se')),
            matching: find.byType(SelectableText),
          ),
        )
        .data!;
    const bayGio = gioThu ~/ 1000;
    var g = giaiMaToken(tokenTuLink(link())!, bayGio: bayGio);
    expect(g.hetHan, bayGio + 7 * 86400);
    expect((g.ten, g.viDo, g.kinhDo), ('Hồ Gươm', 21.0285111, 105.8521822));
    await tester.tap(find.text('30 ngày'));
    await tester.pumpAndSettle();
    g = giaiMaToken(tokenTuLink(link())!, bayGio: bayGio);
    expect(g.hetHan, bayGio + 30 * 86400);
    await tester.ensureVisible(find.byKey(const ValueKey('gui-link')));
    await tester.tap(find.byKey(const ValueKey('gui-link')));
    await tester.pumpAndSettle();
    expect(nt.chiaSe.single, link());
    expect(link(), startsWith('https://compass.tsudev.com/w/'));
  });

  testWidgets('cờ chia sẻ tắt -> không tạo link', (tester) async {
    datManHinh(tester, o.manHinh);
    await tester.pumpWidget(
      dung(ManChiaSe(diem: diemThu[0]), o, ghiDe(chiaSe: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chia sẻ đang tạm tắt.'), findsOneWidget);
    expect(find.byType(VeQr), findsNothing);
  });

  testWidgets('chi tiết điểm ẩn nút Chia sẻ khi cờ tắt', (tester) async {
    datManHinh(tester, o.manHinh);
    for (final bat in [true, false]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        dung(
          const ManChiTietDiem(id: 'a'),
          o,
          ghiDe(kho: KhoDiemBoNho(diemThu), chiaSe: bat),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chia-se')),
        bat ? findsOneWidget : findsNothing,
      );
    }
  });
}
