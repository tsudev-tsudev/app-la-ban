import 'package:quyen_loi/src/domain/san_pham.dart';
import 'package:quyen_loi/src/du_lieu/cua_hang.dart';

/// Cửa hàng rỗng cho app "La bàn Pro" (M2, Q56): app trả phí một lần không
/// bán gói trong app, quyền lợi `pro_app` chỉ đến từ `/v1/status`. Không mở
/// kết nối Play Billing.
final class CuaHangKhongBan implements CuaHang {
  const new();

  @override
  Future<bool> khaDung() async => false;

  @override
  Future<List<GoiBan>> taiGoi() async => const [];

  @override
  Stream<List<GiaoDich>> get capNhat => const Stream.empty();

  @override
  Future<bool> mua(GoiBan goi, {required String maTaiKhoan}) async => false;

  @override
  Future<List<GiaoDich>> khoiPhuc() async => const [];

  @override
  Future<List<GiaoDich>> chuaXacNhan() async => const [];

  @override
  Future<void> hoanTat(GiaoDich g) async {}
}
