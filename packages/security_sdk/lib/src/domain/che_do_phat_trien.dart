import 'package:flutter/foundation.dart';

/// Trạng thái Developer options / gỡ lỗi của máy (S11, QUYET_DINH Q57).
///
/// App chỉ ĐỌC và BÁO (tham số `pt` của `/v1/status`, đã ký); Worker là nơi
/// chặn API. Màn chặn ở app là trải nghiệm (hiện ngay, kể cả offline).
@immutable
final class TrangThaiPhatTrien {
  const new({this.devMode = false, this.adb = false, this.adbWifi = false});

  /// Map từ kênh native; thiếu khoá = false (máy / bản cũ không đọc được).
  factory tuMap(Map<Object?, Object?>? m) => TrangThaiPhatTrien(
    devMode: m?['devMode'] == true,
    adb: m?['adb'] == true,
    adbWifi: m?['adbWifi'] == true,
  );

  static const sach = TrangThaiPhatTrien();

  final bool devMode;
  final bool adb;
  final bool adbWifi;

  /// Bất kỳ công tắc nào đang bật.
  bool get bat => devMode || adb || adbWifi;

  /// Giá trị `pt` gửi server.
  String get thamSo => bat ? '1' : '0';

  @override
  bool operator ==(Object other) =>
      other is TrangThaiPhatTrien &&
      other.devMode == devMode &&
      other.adb == adb &&
      other.adbWifi == adbWifi;

  @override
  int get hashCode => Object.hash(devMode, adb, adbWifi);
}

/// Khoá kill-switch trong `tat` của Remote Config ký số (four-eyes ở SOC):
/// có khoá này -> app không hiện màn chặn (sự cố / đợt duyệt store).
const khoaTatChanPhatTrien = 'chanDevMode';

/// App có hiện màn chặn không. [banProd]: chỉ bản prod chặn (dev / staging chỉ
/// ghi nhận để thử trên máy thật qua ADB - Q57). [mayChuBao]: `/v1/status`
/// gần nhất báo đang chặn. Không có miễn trừ theo thiết bị.
bool canChanPhatTrien({
  required TrangThaiPhatTrien cucBo,
  required bool banProd,
  required bool mayChuBao,
  required Set<String> tatTuXa,
}) {
  if (!banProd || tatTuXa.contains(khoaTatChanPhatTrien)) return false;
  return cucBo.bat || mayChuBao;
}
