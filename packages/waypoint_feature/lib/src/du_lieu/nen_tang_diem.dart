import 'package:flutter/services.dart';
import 'package:waypoint_feature/src/du_lieu/kho_diem.dart';

/// Thao tác cần nền tảng: chọn ảnh, lưu / mở tệp (Storage Access Framework -
/// không cần quyền bộ nhớ), bảng chia sẻ hệ thống. Plugin nội bộ, không SDK
/// bên thứ ba.
abstract interface class NenTangDiem {
  /// Chọn 1 ảnh -> JPEG đã thu nhỏ (cạnh dài <= 1600 px), xoay đúng chiều,
  /// BỎ EXIF (kể cả GPS). null = người dùng huỷ.
  Future<AnhMoi?> chonAnh();

  /// Hộp thoại "Lưu thành" của hệ thống. false = người dùng huỷ.
  Future<bool> luuTep(String tenGoiY, String mime, Uint8List duLieu);

  /// Hộp thoại mở tệp. null = huỷ. Tệp > 20 MB -> [PlatformException].
  Future<Uint8List?> moTep();

  /// Bảng chia sẻ của hệ thống với một đoạn chữ.
  Future<void> chiaSeChu(String chu, {required String tieuDe});
}

/// Gọi plugin `DiemPlugin` (Kotlin, `packages/waypoint_feature/android`).
final class NenTangDiemKenh implements NenTangDiem {
  const new();

  static const _kenh = MethodChannel('la_ban/diem');

  @override
  Future<AnhMoi?> chonAnh() async {
    final m = await _kenh.invokeMapMethod<String, Object?>('chonAnh');
    if (m == null) return null;
    return (
      duLieu: m['duLieu']! as Uint8List,
      rong: m['rong']! as int,
      cao: m['cao']! as int,
    );
  }

  @override
  Future<bool> luuTep(String tenGoiY, String mime, Uint8List duLieu) async =>
      await _kenh.invokeMethod<bool>('luuTep', {
        'ten': tenGoiY,
        'mime': mime,
        'duLieu': duLieu,
      }) ??
      false;

  @override
  Future<Uint8List?> moTep() => _kenh.invokeMethod<Uint8List>('moTep');

  @override
  Future<void> chiaSeChu(String chu, {required String tieuDe}) =>
      _kenh.invokeMethod<void>('chiaSeChu', {'chu': chu, 'tieuDe': tieuDe});
}
