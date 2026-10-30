import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_feature/src/domain/ban_do.dart';
import 'package:map_feature/src/du_lieu/vung_offline.dart';

// Tab Bản đồ không gọi tính năng khác (luật lớp): app nối gốc API theo flavor,
// điểm (waypoint_feature), vị trí
// (location_feature), hướng (compass_feature) vào các provider dưới đây.

/// Gốc Worker phục vụ /ban-do (theo flavor).
final gocBanDoProvider = Provider<String>(
  (_) => 'https://compass-api.tsudev.com',
);

/// Điểm vẽ trên bản đồ.
final diemBanDoProvider = Provider<List<DiemBanDo>>((_) => const []);

/// Vị trí hiện tại; null = chưa có (chưa cấp quyền / đang chờ GPS).
/// autoDispose: chỉ bật GPS khi tab đang mở.
final Provider<ViTriBanDo?> viTriBanDoProvider = Provider.autoDispose(
  (_) => null,
);

/// Đã có quyền vị trí chưa (nút "Vị trí của tôi" xin quyền khi chưa có).
final coQuyenViTriBanDoProvider = Provider<bool>((_) => false);

/// Xin quyền vị trí (chỉ gọi từ thao tác người dùng).
final xinQuyenViTriBanDoProvider = Provider<Future<void> Function()>(
  (_) => () async {},
);

/// Phương vị thật (độ, bắc thực khi có vị trí) cho chế độ xoay theo hướng; chỉ
/// được nghe khi chế độ bật.
final Provider<double?> huongBanDoProvider = Provider.autoDispose((_) => null);

/// Mở chi tiết một điểm khi chạm trên bản đồ (app đẩy màn của
/// waypoint_feature).
final moDiemBanDoProvider = Provider<void Function(BuildContext, String id)?>(
  (_) => null,
);

final khoVungOfflineProvider = Provider<KhoVungOffline>(
  (_) => const KhoVungMapLibre(),
);

/// false trong test widget: platform view MapLibre không vẽ được -> nền phẳng
/// thay bản đồ.
final banDoThatProvider = Provider<bool>((_) => true);

/// Đồng hồ (ms UTC) - test cố định.
final gioBanDoProvider = Provider<int Function()>(
  (_) =>
      () => DateTime.now().toUtc().millisecondsSinceEpoch,
);

/// Đổi mốc UTC (ms) sang giờ địa phương - test cố định múi giờ để golden
/// không phụ thuộc máy chạy.
final gioDiaPhuongBanDoProvider = Provider<DateTime Function(int msUtc)>(
  (_) =>
      (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal(),
);

/// Khung + zoom đang xem (màn bản đồ cập nhật khi camera dừng) - màn vùng
/// offline tải đúng vùng này.
final khungDangXemProvider =
    NotifierProvider<KhungDangXem, ({KhungBanDo khung, double zoom})?>(
      KhungDangXem.new,
    );

class KhungDangXem extends Notifier<({KhungBanDo khung, double zoom})?> {
  @override
  ({KhungBanDo khung, double zoom})? build() => null;

  void dat(KhungBanDo khung, double zoom) => state = (khung: khung, zoom: zoom);
}
