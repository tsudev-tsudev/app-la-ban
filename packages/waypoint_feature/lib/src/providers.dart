import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waypoint_feature/src/domain/diem_moc.dart';
import 'package:waypoint_feature/src/du_lieu/kho_diem.dart';
import 'package:waypoint_feature/src/du_lieu/nen_tang_diem.dart';

// Tab Điểm không gọi tính năng khác (luật lớp): app nối vị trí
// (location_feature), cờ tính năng, CSDL vào các provider dưới đây.

/// Kho điểm; null = CSDL không mở (chế độ an toàn) -> chỉ còn xuất GPX.
final khoDiemProvider = Provider<KhoDiem?>((_) => null);

/// Đọc thô điểm khi [khoDiemProvider] null (chế độ an toàn). null = không có.
final docDiemAnToanProvider = Provider<Future<List<DiemMoc>> Function()?>(
  (_) => null,
);

/// Cờ `chiaSe` (kill-switch từ xa / chế độ an toàn tắt).
final choPhepChiaSeProvider = Provider<bool>((_) => true);

final nenTangDiemProvider = Provider<NenTangDiem>(
  (_) => const NenTangDiemKenh(),
);

/// Đồng hồ (ms UTC) - test cố định.
final gioDiemProvider = Provider<int Function()>(
  (_) =>
      () => DateTime.now().toUtc().millisecondsSinceEpoch,
);

/// Đổi mốc UTC (ms) sang giờ địa phương - test cố định múi giờ để golden
/// không phụ thuộc máy chạy.
final gioDiaPhuongProvider = Provider<DateTime Function(int msUtc)>(
  (_) =>
      (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal(),
);

/// Sinh id điểm - test cố định.
final taoIdDiemProvider = Provider<String Function()>((_) => taoIdDiem);

/// Danh sách điểm (rỗng khi không có kho).
final dsDiemProvider = StreamProvider<List<DiemMoc>>((ref) {
  final kho = ref.watch(khoDiemProvider);
  return kho == null ? Stream.value(const []) : kho.theoDoi();
});

/// Một điểm theo id (null khi đã xoá / đang nạp).
DiemMoc? diemTheoId(WidgetRef ref, String id) => ref.watch(
  dsDiemProvider.select((v) => v.value?.where((d) => d.id == id).firstOrNull),
);

/// Vị trí hiện tại cho tab Điểm.
typedef ViTriHienTai = ({
  double viDo,
  double kinhDo,

  /// m trên mực biển; null khi máy không đo được.
  double? caoDo,

  /// Bán kính sai số ngang (m).
  double? saiSoM,
});

/// Trạng thái vị trí: chưa có quyền / đang chờ / có. App override (nối
/// `docViTriProvider` + quyền của location_feature).
sealed class TrangThaiViTri {
  const new();
}

final class ViTriChuaCoQuyen extends TrangThaiViTri {
  const new();
}

final class ViTriDangCho extends TrangThaiViTri {
  const new();
}

final class ViTriCo extends TrangThaiViTri {
  const new(this.viTri);

  final ViTriHienTai viTri;
}

/// autoDispose: chỉ bật GPS khi có màn đang cần.
final Provider<TrangThaiViTri> viTriDiemProvider = Provider.autoDispose(
  (_) => const ViTriChuaCoQuyen(),
);

/// Xin quyền vị trí (chỉ gọi từ thao tác người dùng).
final xinQuyenViTriDiemProvider = Provider<Future<void> Function()>(
  (_) => () async {},
);

/// Định dạng toạ độ theo tuỳ chọn người dùng (DD / DMS / UTM...). Mặc định
/// độ thập phân 6 chữ số (~0,1 m).
final dinhDangToaDoDiemProvider = Provider<String Function(double, double)>(
  (_) =>
      (vi, kinh) => '${vi.toStringAsFixed(6)}, ${kinh.toStringAsFixed(6)}',
);
