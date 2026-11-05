import 'dart:async';

import 'package:app_shell/src/kenh.dart';
import 'package:app_shell/src/lam_cung.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage/storage.dart';

/// Kho lưu trữ đã mở lúc khởi động. null: không mở được (app vẫn chạy ở chế
/// độ an toàn) hoặc test không cần lưu bền.
final khoLuuTruProvider = Provider<KhoLuuTru?>((_) => null);

/// Lý do chế độ an toàn của lần chạy này (null = chạy thường). Cố định cả
/// phiên - đổi chỉ có hiệu lực ở lần mở app sau.
final anToanProvider = Provider<LyDoAnToan?>(
  (ref) => ref.watch(khoLuuTruProvider)?.anToan,
);

/// Giá trị cuối của cờ tính năng (chế độ an toàn tắt hết; kill-switch từ
/// Remote Config ký số - S3; mức rủi ro từ server - S4).
final coTinhNangProvider = Provider<Map<CoTinhNang, bool>>(
  (ref) => tinhCo(
    cucBo: ref.watch(khoLuuTruProvider)?.coCucBo ?? const {},
    tatTuXa: {
      ...coTuTenTuXa(ref.watch(cauHinhTuXaProvider)?.tat ?? const {}),
      // S4: Risk Level MEDIUM trở lên tắt tính năng nhạy cảm.
      ...coTatTheoRuiRo(ref.watch(ruiRoProvider).muc),
    },
    anToan: ref.watch(anToanProvider) != null,
  ),
);

/// Gọi [danhDau] MỘT lần khi app đã ổn định: [cho] sau khung đầu, hoặc sớm
/// hơn nếu người dùng đưa app về nền (thoát bình thường không phải crash).
void theoDoiOnDinh(
  VoidCallback danhDau, {
  Duration cho = const Duration(seconds: 5),
}) {
  var xong = false;
  late final AppLifecycleListener nghe;
  void motLan() {
    if (xong) return;
    xong = true;
    nghe.dispose();
    danhDau();
  }

  nghe = AppLifecycleListener(onHide: motLan);
  WidgetsBinding.instance.addPostFrameCallback((_) => Timer(cho, motLan));
}
