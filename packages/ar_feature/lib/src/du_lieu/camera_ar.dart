import 'package:ar_feature/src/domain/chieu_ar.dart';
import 'package:flutter/services.dart';

/// Luồng xem trước camera sau đang mở: `texture` cho widget `Texture`, kích
/// thước + trường nhìn đã xoay theo màn hình dọc.
typedef XemTruocCamera = ({
  int texture,
  double rong,
  double cao,
  TruongNhin truongNhin,

  /// Số lần xoay 90° theo chiều kim đồng hồ Dart phải tự xoay texture (khi
  /// engine không tự áp ma trận xoay của camera).
  int xoay,
});

/// Lý do không mở được camera.
enum LoiCamera {
  /// Người dùng từ chối quyền (lần này).
  tuChoi,

  /// Từ chối và chọn "không hỏi lại" - chỉ bật lại được trong Cài đặt máy.
  tuChoiHan,

  /// Không có camera sau / camera đang bận / lỗi phần cứng.
  khongCo,
}

final class NgoaiLeCamera implements Exception {
  const new(this.loi);
  final LoiCamera loi;

  @override
  String toString() => 'NgoaiLeCamera($loi)';
}

/// Camera sau cho màn AR. Plugin nội bộ (Camera2, không SDK ngoài); khung
/// hình CHỈ đi thẳng tới GPU để hiển thị - không đọc pixel, không lưu, không
/// gửi.
abstract interface class CameraAr {
  /// Xin quyền (nếu chưa có) rồi mở camera sau. Lỗi: [NgoaiLeCamera].
  Future<XemTruocCamera> mo();

  Future<void> dong();

  /// Mở trang cài đặt của app (bật lại quyền bị từ chối hẳn).
  Future<void> moCaiDat();
}

/// Gọi `CameraArPlugin` (Kotlin, `packages/ar_feature/android`).
final class CameraArKenh implements CameraAr {
  const new();

  static const _kenh = MethodChannel('la_ban/camera_ar');

  @override
  Future<XemTruocCamera> mo() async {
    try {
      final m = (await _kenh.invokeMapMethod<String, Object?>('mo'))!;
      double so(String k) => (m[k]! as num).toDouble();
      return (
        texture: m['texture']! as int,
        rong: so('rong'),
        cao: so('cao'),
        truongNhin: (ngang: so('fovNgang'), doc: so('fovDoc')),
        xoay: (m['xoay'] as int?) ?? 0,
      );
    } on PlatformException catch (e) {
      throw NgoaiLeCamera(switch (e.code) {
        'camera.tuChoi' => LoiCamera.tuChoi,
        'camera.tuChoiHan' => LoiCamera.tuChoiHan,
        _ => LoiCamera.khongCo,
      });
    } on MissingPluginException {
      throw const NgoaiLeCamera(LoiCamera.khongCo);
    }
  }

  @override
  Future<void> dong() async {
    try {
      await _kenh.invokeMethod<void>('dong');
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> moCaiDat() => _kenh.invokeMethod<void>('moCaiDat');
}
