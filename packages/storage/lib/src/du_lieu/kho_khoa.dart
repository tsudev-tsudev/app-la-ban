import 'dart:math';

import 'package:flutter/services.dart';
import 'package:storage/src/domain/khoa_csdl.dart';

/// Nơi cấp khoá CSDL và thư mục dữ liệu riêng của app.
abstract interface class KhoKhoa {
  /// Khoá SQLCipher 32 byte. Lần đầu sinh ngẫu nhiên, sau đó trả đúng khoá cũ.
  Future<Uint8List> layKhoaCsdl();

  /// Thư mục dữ liệu KHÔNG sao lưu (Android `noBackupFilesDir`, iOS
  /// Application Support có cờ loại khỏi backup).
  Future<String> thuMucDuLieu();
}

/// Khoá bọc bằng Android Keystore (StrongBox nếu có) / iOS Keychain
/// ThisDeviceOnly - mã nền tảng ở `android/`, `ios/` của gói này.
final class KhoKhoaNenTang implements KhoKhoa {
  const new();

  static const _kenh = MethodChannel('la_ban/luu_tru');

  @override
  Future<Uint8List> layKhoaCsdl() async {
    final k = await _kenh.invokeMethod<Uint8List>('layKhoaCsdl');
    if (k == null || k.length != doDaiKhoa) {
      throw PlatformException(code: 'khoa.saiDoDai');
    }
    return k;
  }

  @override
  Future<String> thuMucDuLieu() async {
    final t = await _kenh.invokeMethod<String>('thuMucDuLieu');
    if (t == null || t.isEmpty) throw PlatformException(code: 'thuMuc.rong');
    return t;
  }
}

/// Kho trong bộ nhớ cho test / máy dev không có nền tảng.
final class KhoKhoaBoNho implements KhoKhoa {
  new(this._thuMuc, {this._khoa});

  final String _thuMuc;
  Uint8List? _khoa;

  @override
  Future<Uint8List> layKhoaCsdl() async => _khoa ??= Uint8List.fromList(
    List.generate(doDaiKhoa, (_) => Random.secure().nextInt(256)),
  );

  @override
  Future<String> thuMucDuLieu() async => _thuMuc;
}
