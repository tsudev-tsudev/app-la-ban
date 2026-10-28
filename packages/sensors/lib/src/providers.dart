import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors/src/domain/bo_hop_nhat.dart';
import 'package:sensors/src/domain/vi_tri.dart';
import 'package:sensors/src/domain/wmm.dart';
import 'package:sensors/src/du_lieu/dich_vu_huong.dart';
import 'package:sensors/src/du_lieu/nguon_cam_bien.dart';

// Provider dùng chung giữa các tính năng (la bàn, vị trí / telemetry): MỘT
// luồng cảm biến, MỘT vị trí - tính năng không gọi nhau mà cùng đọc ở đây.

/// Nguồn cảm biến. Test / golden override bằng `NguonCamBienGhiSan`.
final nguonCamBienProvider = Provider<NguonCamBien>(
  (_) => const NguonCamBienNenTang(),
);

/// Dịch vụ hợp nhất (isolate riêng). Test override với `dungIsolate: false`.
final dichVuHuongProvider = Provider<DichVuHuong>(
  (ref) => DichVuHuong(ref.watch(nguonCamBienProvider)),
);

/// Hướng hiện tại. autoDispose: không còn màn nào nghe (app xuống nền, rời
/// tab) -> huỷ luồng -> nền tảng tắt cảm biến. Không tự thử lại khi lỗi:
/// máy không có la bàn thì thử lại cũng vô ích.
final StreamProvider<HuongDoc> huongProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(dichVuHuongProvider).theoDoi(),
  retry: (_, _) => null,
);

/// Vị trí dùng tính độ lệch từ, mặt trời / mặt trăng. null tới khi có nguồn
/// vị trí (location_feature đẩy vị trí GPS / vị trí lưu gần nhất).
final viTriProvider = NotifierProvider<ViTriNotifier, ViTriDiaLy?>(
  ViTriNotifier.new,
);

/// Vị trí lưu gần nhất lúc mở app (app override từ kho) - bắc thực bật ngay
/// khung đầu, không chờ GPS.
final viTriBanDauProvider = Provider<ViTriDiaLy?>((_) => null);

class ViTriNotifier extends Notifier<ViTriDiaLy?> {
  @override
  ViTriDiaLy? build() => ref.read(viTriBanDauProvider);

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
