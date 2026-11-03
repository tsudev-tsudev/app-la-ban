import 'package:flutter/services.dart';
import 'package:security_sdk/src/domain/che_do_phat_trien.dart';

/// Đọc trạng thái Developer options + mở màn cài đặt (S11). Tách khỏi
/// `NenTangThietBi` để bản giả trong test chỉ cần cài khi dùng tới.
abstract interface class KenhPhatTrien {
  Future<TrangThaiPhatTrien> doc();

  /// false: máy không mở được màn cài đặt.
  Future<bool> moCaiDat();
}

final class KenhPhatTrienKenh implements KenhPhatTrien {
  const new();

  static const _kenh = MethodChannel('la_ban/thiet_bi');

  @override
  Future<TrangThaiPhatTrien> doc() async {
    try {
      return TrangThaiPhatTrien.tuMap(
        await _kenh.invokeMapMethod<Object?, Object?>('cheDoPhatTrien'),
      );
    } on PlatformException {
      return TrangThaiPhatTrien.sach;
    } on MissingPluginException {
      return TrangThaiPhatTrien.sach;
    }
  }

  @override
  Future<bool> moCaiDat() async {
    try {
      return await _kenh.invokeMethod<bool>('moCaiDatPhatTrien') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
