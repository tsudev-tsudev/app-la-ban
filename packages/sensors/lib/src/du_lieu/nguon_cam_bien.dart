import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sensors/src/domain/mau_cam_bien.dart';

/// Chu kỳ lấy mẫu (µs): 100 Hz khi đang dùng, 20 Hz khi máy đứng yên
/// (Spec §4.1).
const chuKyNhanhUs = 10000;
const chuKyChamUs = 50000;

/// Nơi phát lô mẫu cảm biến (mã hoá phẳng theo [giaiMaLo]).
abstract interface class NguonCamBien {
  Future<KhaNangCamBien> khaNang();

  /// Lô mẫu ~60 lần/giây. Huỷ đăng ký = nền tảng tắt cảm biến (tiết kiệm pin).
  Stream<Float64List> lo({int chuKyUs = chuKyNhanhUs});

  /// Đổi chu kỳ lấy mẫu khi đang phát.
  Future<void> datChuKy(int chuKyUs);
}

/// Plugin nội bộ của gói (`android/`: SensorManager trên luồng riêng, gom lô
/// 16 ms). iOS (CoreMotion + CLHeading) làm ở phase I1 - trên nền tảng chưa
/// có plugin, [khaNang] trả toàn false.
final class NguonCamBienNenTang implements NguonCamBien {
  const new();

  static const _lenh = MethodChannel('la_ban/cam_bien');
  static const _suKien = EventChannel('la_ban/cam_bien/su_kien');

  @override
  Future<KhaNangCamBien> khaNang() async {
    try {
      final m = await _lenh.invokeMapMethod<Object?, Object?>('khaNang');
      return khaNangTuMap(m ?? const {});
    } on MissingPluginException {
      return khaNangTuMap(const {});
    }
  }

  @override
  Stream<Float64List> lo({int chuKyUs = chuKyNhanhUs}) => _suKien
      .receiveBroadcastStream({'chuKyUs': chuKyUs})
      .map((e) => e as Float64List);

  @override
  Future<void> datChuKy(int chuKyUs) =>
      _lenh.invokeMethod<void>('datChuKy', {'chuKyUs': chuKyUs});
}

/// Phát lại các lô đã ghi (test, ảnh chụp golden, chế độ demo).
final class NguonCamBienGhiSan implements NguonCamBien {
  new(this._dsLo, {this._khaNang, this.khoang = Duration.zero});

  final List<Float64List> _dsLo;
  final KhaNangCamBien? _khaNang;

  /// Khoảng nghỉ giữa hai lô (zero = phát liền trong một microtask).
  final Duration khoang;

  /// Các chu kỳ đã được yêu cầu (để test kiểm hạ tần số).
  final List<int> lichSuChuKy = [];

  @override
  Future<KhaNangCamBien> khaNang() async =>
      _khaNang ??
      (
        xoayVector: true,
        xoayGame: true,
        tu: true,
        giaToc: true,
        conQuay: true,
        apSuat: false,
      );

  @override
  Stream<Float64List> lo({int chuKyUs = chuKyNhanhUs}) async* {
    lichSuChuKy.add(chuKyUs);
    for (final l in _dsLo) {
      if (khoang > Duration.zero) await Future<void>.delayed(khoang);
      yield l;
    }
  }

  @override
  Future<void> datChuKy(int chuKyUs) async => lichSuChuKy.add(chuKyUs);
}
