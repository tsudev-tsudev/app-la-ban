import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:test_kit/src/ma_tran.dart';

/// Các ô kiểm trợ năng: máy phổ biến, sáng + tối, vi + en, chữ x1 và x2
/// (chữ to là lúc nút dễ bị ép nhỏ / chữ đè nhau nhất).
final oTroNang = <OMaTran>[
  for (final s in Brightness.values)
    (manHinh: manHinh12[1], sang: s, ngonNgu: LbNgonNgu.vi, coChu: 1.0),
  (
    manHinh: manHinh12[1],
    sang: Brightness.light,
    ngonNgu: LbNgonNgu.en,
    coChu: 2.0,
  ),
];

/// Audit trợ năng (A8b) cho một màn: vùng chạm >= 48 dp (Android) / 44 pt
/// (iOS), mọi nút có nhãn đọc được cho TalkBack / VoiceOver, chữ đạt tương
/// phản WCAG AA. [dung] như [kiemMaTran]; [truocKhiKiem] để mở menu / cuộn
/// tới phần cần kiểm.
Future<void> kiemTroNang(
  WidgetTester tester,
  Widget Function(OMaTran o) dung, {
  Iterable<OMaTran>? dsO,
  Future<void> Function()? truocKhiKiem,
  bool kiemTuongPhan = true,
}) async {
  final semantics = tester.ensureSemantics();
  for (final o in dsO ?? oTroNang) {
    datManHinh(tester, o.manHinh);
    await tester.pumpWidget(dung(o));
    await tester.pump(const Duration(seconds: 2));
    await truocKhiKiem?.call();
    final nhan = '${o.sang.name} ${o.ngonNgu} x${o.coChu}';
    await expectLater(
      tester,
      meetsGuideline(androidTapTargetGuideline),
      reason: 'vùng chạm Android ($nhan)',
    );
    await expectLater(
      tester,
      meetsGuideline(iOSTapTargetGuideline),
      reason: 'vùng chạm iOS ($nhan)',
    );
    await expectLater(
      tester,
      meetsGuideline(labeledTapTargetGuideline),
      reason: 'nhãn nút ($nhan)',
    );
    if (kiemTuongPhan) {
      await expectLater(
        tester,
        meetsGuideline(textContrastGuideline),
        reason: 'tương phản chữ ($nhan)',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }
  semantics.dispose();
}
