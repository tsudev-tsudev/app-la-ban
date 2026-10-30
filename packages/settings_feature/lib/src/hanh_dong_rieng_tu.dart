import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thao tác nền tảng của màn Quyền riêng tư. App nối (tính năng không gọi
/// nhau, settings_feature không biết CSDL / SDK bảo mật); trường null -> ẩn
/// nút tương ứng.
final class HanhDongRiengTu {
  const new({
    this.demDiem,
    this.xuatDuLieu,
    this.xoaToanBo,
    this.maThietBi,
    this.moLienKet,
    this.moCaiDatHeThong,
  });

  /// Số điểm mốc đang lưu.
  final Future<int> Function()? demDiem;

  /// Ghi tệp JSON (người dùng chọn nơi lưu). true = đã lưu.
  final Future<bool> Function()? xuatDuLieu;

  /// Xoá MỌI dữ liệu của app (tệp, CSDL, bản đồ offline, khoá Keystore) rồi
  /// đóng app.
  final Future<void> Function()? xoaToanBo;

  /// Mã thiết bị máy chủ cấp (null = chưa đăng ký).
  final String? Function()? maThietBi;

  /// Mở trang web của La bàn / thư tới hộp thư quyền riêng tư.
  final Future<bool> Function(Uri)? moLienKet;

  /// Trang cài đặt ứng dụng của hệ điều hành (thu hồi quyền).
  final Future<void> Function()? moCaiDatHeThong;
}

final hanhDongRiengTuProvider = Provider<HanhDongRiengTu>(
  (_) => const HanhDongRiengTu(),
);
