import 'dart:async';

import 'package:flutter/services.dart';
import 'package:location_feature/src/domain/doc_vi_tri.dart';

/// Nơi phát vị trí + quản lý quyền.
abstract interface class NguonViTri {
  Future<QuyenViTri> quyen();

  /// Hiện hộp thoại quyền hệ thống (chỉ gọi khi người dùng bấm).
  Future<QuyenViTri> xinQuyen();

  /// Dịch vụ vị trí của máy đang bật.
  Future<bool> dichVuBat();

  Future<void> moCaiDatApp();

  Future<void> moCaiDatViTri();

  /// Luồng vị trí; huỷ nghe = nền tảng thôi cập nhật (tiết kiệm pin).
  Stream<DocViTri> theoDoi({int chuKyMs = 1000});
}

/// Plugin nội bộ của gói (`android/`: LocationManager, không Play
/// Services). iOS (CoreLocation) ở phase I1 - nền tảng chưa có plugin coi
/// như chưa có quyền.
final class NguonViTriNenTang implements NguonViTri {
  const new();

  static const _lenh = MethodChannel('la_ban/vi_tri');
  static const _suKien = EventChannel('la_ban/vi_tri/su_kien');

  Future<T?> _goi<T>(String ten) async {
    try {
      return await _lenh.invokeMethod<T>(ten);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<QuyenViTri> quyen() async => quyenTuChuoi(await _goi<String>('quyen'));

  @override
  Future<QuyenViTri> xinQuyen() async =>
      quyenTuChuoi(await _goi<String>('xinQuyen'));

  @override
  Future<bool> dichVuBat() async => await _goi<bool>('dichVuBat') ?? false;

  @override
  Future<void> moCaiDatApp() => _goi<void>('moCaiDatApp');

  @override
  Future<void> moCaiDatViTri() => _goi<void>('moCaiDatViTri');

  @override
  Stream<DocViTri> theoDoi({int chuKyMs = 1000}) => _suKien
      .receiveBroadcastStream({'chuKyMs': chuKyMs})
      .map(giaiMaDocViTri)
      .where((d) => d != null)
      .cast<DocViTri>();
}

/// Phát lại vị trí ghi sẵn (test, golden, chế độ demo).
final class NguonViTriGhiSan implements NguonViTri {
  new(
    this._ds, {
    this.quyenHienTai = QuyenViTri.chinhXac,
    this.quyenSauKhiXin = QuyenViTri.chinhXac,
    this.dichVu = true,
  });

  final List<DocViTri> _ds;
  QuyenViTri quyenHienTai;
  final QuyenViTri quyenSauKhiXin;
  bool dichVu;
  int soLanXin = 0;
  int soLanMoCaiDat = 0;

  @override
  Future<QuyenViTri> quyen() async => quyenHienTai;

  @override
  Future<QuyenViTri> xinQuyen() async {
    soLanXin++;
    return quyenHienTai = quyenSauKhiXin;
  }

  @override
  Future<bool> dichVuBat() async => dichVu;

  @override
  Future<void> moCaiDatApp() async => soLanMoCaiDat++;

  @override
  Future<void> moCaiDatViTri() async => soLanMoCaiDat++;

  @override
  Stream<DocViTri> theoDoi({int chuKyMs = 1000}) => Stream.fromIterable(_ds);
}
