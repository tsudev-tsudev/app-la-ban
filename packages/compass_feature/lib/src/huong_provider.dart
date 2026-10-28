import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors/sensors.dart';

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
