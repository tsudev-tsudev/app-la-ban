import 'package:ar_feature/src/domain/chieu_ar.dart';
import 'package:ar_feature/src/du_lieu/camera_ar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Camera AR không gọi tính năng khác (luật lớp): app nối hướng (sensors +
// WMM của compass_feature), điểm + vị trí (waypoint_feature, location_feature)
// vào các provider dưới đây.

/// Tư thế camera cho lớp phủ: phương vị bắc thực, góc ngóc, nghiêng ngang.
typedef DocAr = ({
  TuTheCamera camera,

  /// Máy đang dựng đứng (phương vị theo camera sau). false -> nhắc giữ thẳng.
  bool dungDung,

  /// La bàn cần hiệu chuẩn / nhiễu từ -> nhắc hiệu chuẩn.
  bool canHieuChuan,
});

/// Một điểm lưu nhìn từ vị trí hiện tại.
typedef DiemAr = ({
  String id,
  String ten,

  /// Phương vị bắc thực tới điểm (độ).
  double phuongVi,
  double khoangCachM,

  /// Góc ngóc tới điểm (độ) - 0 khi không biết cao độ.
  double ngoc,
});

/// Hướng hiện tại; null khi cảm biến chưa có số đo. autoDispose: chỉ chạy
/// cảm biến khi màn AR đang mở.
final Provider<DocAr?> docArProvider = Provider.autoDispose((_) => null);

/// Điểm lưu (gần nhất trước); rỗng khi chưa có vị trí.
final Provider<List<DiemAr>> diemArProvider = Provider.autoDispose(
  (_) => const [],
);

/// Đã có vị trí chưa (không có thì chỉ phủ hướng, nhắc bật vị trí).
final Provider<bool> coViTriArProvider = Provider.autoDispose((_) => false);

/// Camera sau - test thay bằng bản giả.
final cameraArProvider = Provider<CameraAr>((_) => const CameraArKenh());
