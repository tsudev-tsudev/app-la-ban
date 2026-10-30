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

final String hopLe = maHoaToken(diemThu[0], hetHan: gioThu ~/ 1000 + 3600);
final String quaHan = maHoaToken(diemThu[0], hetHan: gioThu ~/ 1000 - 1);

void main() {
  setUpAll(napFontThat);

  testWidgets('nhận link: ma trận không tràn + golden', (tester) async {
    await kiemMaTran(
      tester,
      (o) => dung(ManNhanDiem(token: hopLe, moDanhSach: () {}), o, ghiDe()),
    );
    await chupGolden(
      tester,
      'man_nhan_diem',
      (o) => dung(ManNhanDiem(token: hopLe, moDanhSach: () {}), o, ghiDe()),
    );
  });

  testWidgets('lưu điểm nhận được vào kho rồi về danh sách', (tester) async {
    datManHinh(tester, o.manHinh);
    final kho = KhoDiemBoNho();
    var ve = 0;
    await tester.pumpWidget(
      dung(
        ManNhanDiem(token: hopLe, moDanhSach: () => ve++),
        o,
        ghiDe(kho: kho),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gặp ở cổng đền Ngọc Sơn'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('luu-diem-nhan')));
    await tester.tap(find.byKey(const ValueKey('luu-diem-nhan')));
    await tester.pumpAndSettle();
    final d = (await kho.tatCa()).single;
    expect(
      (d.id, d.ten, d.viDo, d.caoDo),
      ('id-0', 'Hồ Gươm', 21.0285111, 12.3),
    );
    expect(ve, 1);
  });

  testWidgets('link hết hạn / hỏng / không có kho', (tester) async {
    datManHinh(tester, o.manHinh);
    for (final (t, chu) in [
      (quaHan, 'Link đã hết hạn. Hãy nhờ người gửi chia sẻ lại.'),
      ('AQ', 'Link không hợp lệ hoặc bị cắt mất khi gửi.'),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        dung(ManNhanDiem(token: t, moDanhSach: () {}), o, ghiDe()),
      );
      await tester.pumpAndSettle();
      expect(find.text(chu), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      dung(
        ManNhanDiem(token: hopLe, moDanhSach: () {}),
        o,
        ghiDe(khongKho: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('luu-diem-nhan')), findsNothing);
    expect(find.byKey(const ValueKey('dan-duong-nhan')), findsOneWidget);
  });
}
