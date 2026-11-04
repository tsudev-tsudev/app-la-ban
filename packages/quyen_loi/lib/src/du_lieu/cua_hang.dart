import 'package:meta/meta.dart';
import 'package:quyen_loi/src/domain/san_pham.dart';

/// Trạng thái giao dịch Play đã quy về domain.
enum LoaiGiaoDich { choThanhToan, daMua, khoiPhuc, loi, huy }

/// Một giao dịch từ cửa hàng. [nguon] = đối tượng của plugin (để hoàn tất).
@immutable
final class GiaoDich {
  const new({
    required this.maSanPham,
    required this.token,
    required this.loai,
    this.canHoanTat = false,
    this.nguon,
  });

  final String maSanPham;

  /// Purchase token (gửi máy chủ, KHÔNG ghi log / lưu thô).
  final String token;
  final LoaiGiaoDich loai;

  /// Play chờ app xác nhận (acknowledge) - chỉ làm sau khi máy chủ đã nhận.
  final bool canHoanTat;
  final Object? nguon;

  SanPham? get sanPham => SanPham.tuMa(maSanPham);
}

/// Cửa hàng (Google Play Billing qua `in_app_purchase`; test dùng bản giả).
abstract interface class CuaHang {
  /// Billing dùng được trên máy này.
  Future<bool> khaDung();

  /// Gói đang bán (giá theo vùng do Play trả).
  Future<List<GoiBan>> taiGoi();

  /// Giao dịch mới / khôi phục / đổi trạng thái.
  Stream<List<GiaoDich>> get capNhat;

  /// Mở luồng mua của Play; false = không mở được. [maTaiKhoan] =
  /// `obfuscatedAccountId` (băm định danh cài đặt, không định danh phần cứng).
  Future<bool> mua(GoiBan goi, {required String maTaiKhoan});

  /// Giao dịch còn hiệu lực của tài khoản Google đang đăng nhập Play (gói
  /// đăng ký đang chạy, mua một lần chưa hoàn tiền) - dùng cho Khôi phục.
  Future<List<GiaoDich>> khoiPhuc();

  /// Giao dịch đã thanh toán nhưng chưa được xác nhận (app bị tắt giữa chừng /
  /// mất mạng lúc xác minh) - thử xác minh lại khi mở app.
  Future<List<GiaoDich>> chuaXacNhan();

  /// Báo Play đã xử lý xong (acknowledge) - CHỈ sau khi máy chủ nhận.
  Future<void> hoanTat(GiaoDich g);
}
