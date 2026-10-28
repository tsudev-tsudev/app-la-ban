import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors/sensors.dart';

/// Vị trí dùng tính độ lệch từ. null tới khi có nguồn vị trí (A4 đẩy vị trí
/// GPS / vị trí lưu gần nhất qua [ViTriNotifier.viTri]).
final viTriProvider = NotifierProvider<ViTriNotifier, ViTriDiaLy?>(
  ViTriNotifier.new,
);

class ViTriNotifier extends Notifier<ViTriDiaLy?> {
  @override
  ViTriDiaLy? build() => null;

  ViTriDiaLy? get viTri => state;

  set viTri(ViTriDiaLy? v) => state = v;
}

/// Hệ số WMM: bản nhúng sẵn, config ký số (S3) override khi có bản mới.
final heSoWmmProvider = Provider<HeSoWmm>((_) => HeSoWmm.wmm2025);

/// Đồng hồ (test override để cố định ngày).
final dongHoProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Từ trường WMM tại vị trí hiện tại; chỉ tính lại khi đổi vị trí / hệ số
/// (độ lệch đổi < 0,2°/năm, không cần theo từng khung hình).
final tuTruongProvider = Provider<TuTruongDiaCau?>((ref) {
  final v = ref.watch(viTriProvider);
  if (v == null) return null;
  return tinhTuTruong(
    ref.watch(heSoWmmProvider),
    viDo: v.viDo,
    kinhDo: v.kinhDo,
    doCaoKm: v.doCaoM / 1000,
    nam: namThapPhan(ref.watch(dongHoProvider)()),
  );
});

/// Rung nhẹ (test override để đếm).
final rungProvider = Provider<void Function()>(
  (_) => HapticFeedback.selectionClick,
);
