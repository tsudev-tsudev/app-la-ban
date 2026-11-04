import 'package:meta/meta.dart';
import 'package:quyen_loi/src/domain/quyen_loi.dart';
import 'package:quyen_loi/src/domain/san_pham.dart';

/// Lỗi hiện cho người dùng (mỗi mã một chuỗi ARB).
enum LoiMua {
  /// Không kết nối được máy chủ / Google - giao dịch giữ lại, thử lại sau.
  mang,

  /// Cửa hàng Play từ chối mở luồng mua / lỗi Billing.
  cuaHang,

  /// Máy chủ không xác minh được giao dịch với Google.
  tokenSai,

  /// Một giao dịch đã dùng trên quá nhiều thiết bị (IAP-04).
  quaSoThietBi,

  /// Bản app không do Google Play cài (IAP-05).
  khongPhaiBanPlay,

  /// Thiết bị đang bị hạn chế / chặn hoặc lỗi máy chủ khác.
  mayChu,

  /// Khôi phục xong nhưng không thấy giao dịch nào của tài khoản Google này.
  khongCoGiaoDich,
}

/// Hàm THUẦN: phản hồi lỗi của `POST /v1/mua/xac-minh` -> lỗi hiển thị.
/// [status] 0 = không tới được máy chủ.
LoiMua loiTuPhanHoi(int status, String? ma) => switch ((status, ma)) {
  (0, _) => LoiMua.mang,
  (503, _) => LoiMua.mang,
  (_, 'token-sai') => LoiMua.tokenSai,
  (_, 'token-qua-so-thiet-bi') => LoiMua.quaSoThietBi,
  (_, 'khong-phai-ban-play') => LoiMua.khongPhaiBanPlay,
  _ => LoiMua.mayChu,
};

/// Lỗi có nên giữ giao dịch để thử xác minh lại lần sau không (lỗi tạm thời).
/// Lỗi dứt khoát -> không hoàn tất (Play tự hoàn tiền giao dịch không được
/// xác nhận trong 3 ngày).
bool thuLaiDuoc(LoiMua l) => l == LoiMua.mang || l == LoiMua.mayChu;

/// Giai đoạn của màn Paywall.
enum GiaiDoanMua {
  /// Đang hỏi Play danh sách gói.
  dangTai,

  /// Thiết bị không có Play / Billing (bản không có Google Play, chưa đăng
  /// nhập...) hoặc Play chưa có sản phẩm nào.
  khongKhaDung,

  /// Đã có gói, chờ người dùng chọn.
  sanSang,

  /// Đang mở luồng mua của Play.
  dangMua,

  /// Play báo thanh toán đang chờ (tiền mặt / chuyển khoản...).
  choThanhToan,

  /// Đang gửi giao dịch cho máy chủ xác minh.
  dangXacMinh,

  /// Máy chủ đã cấp quyền lợi.
  thanhCong,
}

/// Trạng thái màn Paywall (bất biến).
@immutable
final class TrangThaiMua {
  const new({
    this.giaiDoan = GiaiDoanMua.dangTai,
    this.goi = const [],
    this.loi,
    this.dangKhoiPhuc = false,
  });

  final GiaiDoanMua giaiDoan;
  final List<GoiBan> goi;
  final LoiMua? loi;
  final bool dangKhoiPhuc;

  /// Đang có thao tác chạy -> khoá các nút mua / khôi phục.
  bool get ban =>
      dangKhoiPhuc ||
      giaiDoan == GiaiDoanMua.dangMua ||
      giaiDoan == GiaiDoanMua.dangXacMinh;

  TrangThaiMua _voi({
    GiaiDoanMua? giaiDoan,
    List<GoiBan>? goi,
    LoiMua? loi,
    bool boLoi = false,
    bool? dangKhoiPhuc,
  }) => TrangThaiMua(
    giaiDoan: giaiDoan ?? this.giaiDoan,
    goi: goi ?? this.goi,
    loi: boLoi ? null : loi ?? this.loi,
    dangKhoiPhuc: dangKhoiPhuc ?? this.dangKhoiPhuc,
  );
}

/// Sự kiện của luồng mua.
sealed class SuKienMua {
  const new();
}

/// Mở lại Paywall: chưa có gói -> hiện chỗ chờ.
final class BatDauTai extends SuKienMua {
  const new();
}

final class DaTaiGoi extends SuKienMua {
  const new(this.goi);
  final List<GoiBan> goi;
}

final class CuaHangKhongKhaDung extends SuKienMua {
  const new();
}

final class BatDauMua extends SuKienMua {
  const new();
}

/// Play không mở được luồng mua.
final class MoMuaLoi extends SuKienMua {
  const new();
}

final class NguoiDungHuy extends SuKienMua {
  const new();
}

final class ChoThanhToan extends SuKienMua {
  const new();
}

final class BatDauXacMinh extends SuKienMua {
  const new();
}

final class XacMinhXong extends SuKienMua {
  const new(this.quyenLoi);
  final QuyenLoi quyenLoi;
}

final class XacMinhLoi extends SuKienMua {
  const new(this.loi);
  final LoiMua loi;
}

final class BatDauKhoiPhuc extends SuKienMua {
  const new();
}

/// Khôi phục xong; [thayGiaoDich] = Play trả ít nhất một giao dịch.
final class KhoiPhucXong extends SuKienMua {
  const new({required this.thayGiaoDich});
  final bool thayGiaoDich;
}

final class BoLoi extends SuKienMua {
  const new();
}

/// Hàm THUẦN: máy trạng thái của Paywall.
TrangThaiMua chuyenTrangThai(TrangThaiMua s, SuKienMua e) => switch (e) {
  BatDauTai() => s.goi.isEmpty ? s._voi(giaiDoan: GiaiDoanMua.dangTai) : s,
  DaTaiGoi(:final goi) => s._voi(
    giaiDoan:
        s.giaiDoan == GiaiDoanMua.dangTai ||
            s.giaiDoan == GiaiDoanMua.khongKhaDung
        ? (goi.isEmpty ? GiaiDoanMua.khongKhaDung : GiaiDoanMua.sanSang)
        : s.giaiDoan,
    goi: sapXepGoi(goi),
  ),
  CuaHangKhongKhaDung() => s._voi(giaiDoan: GiaiDoanMua.khongKhaDung),
  BatDauMua() => s.ban ? s : s._voi(giaiDoan: GiaiDoanMua.dangMua, boLoi: true),
  MoMuaLoi() => s._voi(giaiDoan: _veSanSang(s), loi: LoiMua.cuaHang),
  NguoiDungHuy() => s._voi(giaiDoan: _veSanSang(s)),
  ChoThanhToan() => s._voi(giaiDoan: GiaiDoanMua.choThanhToan),
  BatDauXacMinh() => s._voi(giaiDoan: GiaiDoanMua.dangXacMinh, boLoi: true),
  XacMinhXong(:final quyenLoi) => s._voi(
    giaiDoan: quyenLoi.pro ? GiaiDoanMua.thanhCong : _veSanSang(s),
    dangKhoiPhuc: false,
    boLoi: true,
  ),
  XacMinhLoi(:final loi) => s._voi(
    giaiDoan: _veSanSang(s),
    loi: loi,
    dangKhoiPhuc: false,
  ),
  BatDauKhoiPhuc() => s.ban ? s : s._voi(dangKhoiPhuc: true, boLoi: true),
  KhoiPhucXong(:final thayGiaoDich) => s._voi(
    dangKhoiPhuc: false,
    loi: thayGiaoDich ? null : LoiMua.khongCoGiaoDich,
    boLoi: thayGiaoDich,
  ),
  BoLoi() => s._voi(boLoi: true),
};

GiaiDoanMua _veSanSang(TrangThaiMua s) =>
    s.goi.isEmpty ? GiaiDoanMua.khongKhaDung : GiaiDoanMua.sanSang;
