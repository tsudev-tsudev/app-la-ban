import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:quyen_loi/src/domain/luong_mua.dart';
import 'package:quyen_loi/src/domain/quyen_loi.dart';
import 'package:quyen_loi/src/domain/san_pham.dart';
import 'package:quyen_loi/src/du_lieu/cua_hang.dart';

/// Kết quả `POST /v1/mua/xac-minh`: quyền lợi máy chủ cấp, hoặc lỗi.
typedef KetQuaXacMinh = ({QuyenLoi? quyenLoi, LoiMua? loi});

/// Gửi giao dịch cho Worker (yêu cầu ký S3). App nối.
typedef XacMinhMua = Future<KetQuaXacMinh> Function(
  SanPham sanPham,
  String token,
);

/// Nơi lưu bản quyền lợi gần nhất (tệp JSON trong thư mục app).
abstract interface class KhoQuyenLoi {
  Map<String, Object?> doc();
  Future<void> ghi(Map<String, Object?> duLieu);
}

final class KhoQuyenLoiBoNho implements KhoQuyenLoi {
  Map<String, Object?> _d = const {};

  @override
  Map<String, Object?> doc() => _d;

  @override
  Future<void> ghi(Map<String, Object?> duLieu) async => _d = duLieu;
}

/// `obfuscatedAccountId` gửi Play: SHA-256 hex của định danh cài đặt (64 ký
/// tự - đúng giới hạn của Play), không định danh phần cứng.
String maTaiKhoanTuCaiDat(String installationId) =>
    sha256.convert(utf8.encode('la-ban/play/$installationId')).toString();

/// Quyền lợi Pro + luồng mua (M1a bước 2). Quyền lợi chỉ đổi theo phản hồi
/// của máy chủ (`/v1/status` hoặc `/v1/mua/xac-minh`) - IAP-01.
final class DichVuQuyenLoi extends ChangeNotifier {
  new({
    required this.cuaHang,
    required this.xacMinh,
    required this.kho,
    required this.maTaiKhoan,
    int Function()? dongHo,
  }) : _dongHo = dongHo ?? _gioHeThong {
    final d = kho.doc();
    _daLuu = QuyenLoi.tuJson(d['quyenLoi']);
    final n = d['nhanLuc'];
    _nhanLuc = n is int ? n : null;
  }

  final CuaHang cuaHang;
  final XacMinhMua xacMinh;
  final KhoQuyenLoi kho;

  /// Lazy: định danh cài đặt đọc khi cần mua.
  final String Function() maTaiKhoan;
  final int Function() _dongHo;

  static int _gioHeThong() => DateTime.now().millisecondsSinceEpoch;

  QuyenLoi? _daLuu;
  int? _nhanLuc;
  TrangThaiMua _mua = const TrangThaiMua();
  StreamSubscription<List<GiaoDich>>? _nghe;
  final _dangXacMinh = <String>{};
  bool _dong = false;

  /// Quyền lợi đang áp dụng (có ân hạn offline).
  TrangThaiQuyenLoi get trangThai =>
      tinhQuyenLoi(daLuu: _daLuu, nhanLuc: _nhanLuc, bayGio: _dongHo());

  /// Trạng thái màn Paywall.
  TrangThaiMua get mua => _mua;

  void _phat(SuKienMua e) {
    if (_dong) return;
    _mua = chuyenTrangThai(_mua, e);
    notifyListeners();
  }

  /// Nghe giao dịch của Play (phải nghe sớm để không lỡ cập nhật).
  void batDau() {
    _nghe ??= cuaHang.capNhat.listen(
      (ds) => unawaited(_xuLy(ds)),
      onError: (Object _) => _phat(const MoMuaLoi()),
    );
  }

  /// Giao dịch đã thanh toán nhưng chưa xác nhận (app tắt / mất mạng giữa
  /// chừng) -> gửi lại máy chủ. Gọi khi cổng trực tuyến mở.
  Future<void> thuLaiChuaXacNhan() async {
    if (!await cuaHang.khaDung()) return;
    for (final g in await cuaHang.chuaXacNhan()) {
      await _xacMinh(g, imLang: true);
    }
  }

  /// Phản hồi `/v1/status` mới: lưu + áp dụng.
  Future<void> capNhatTuMayChu(QuyenLoi q) async {
    final cu = trangThai;
    _daLuu = q;
    _nhanLuc = _dongHo();
    await kho.ghi({'quyenLoi': q.toJson(), 'nhanLuc': _nhanLuc});
    final moi = trangThai;
    if (!_dong && (cu.muc != moi.muc || cu.quyenLoi != moi.quyenLoi)) {
      notifyListeners();
    }
  }

  /// Mở Paywall: hỏi Play danh sách gói (giá theo vùng).
  Future<void> taiGoi() async {
    _phat(const BatDauTai());
    if (!await cuaHang.khaDung()) {
      _phat(const CuaHangKhongKhaDung());
      return;
    }
    _phat(DaTaiGoi(await cuaHang.taiGoi()));
  }

  /// Mua gói [g]: mở luồng Play; kết quả về qua [CuaHang.capNhat].
  Future<void> muaGoi(GoiBan g) async {
    if (_mua.ban) return;
    _phat(const BatDauMua());
    final mo = await cuaHang.mua(g, maTaiKhoan: maTaiKhoan());
    if (!mo) _phat(const MoMuaLoi());
  }

  /// Khôi phục: gửi lại mọi giao dịch còn hiệu lực của tài khoản Google.
  Future<void> khoiPhuc() async {
    if (_mua.ban) return;
    _phat(const BatDauKhoiPhuc());
    if (!await cuaHang.khaDung()) {
      _phat(const XacMinhLoi(LoiMua.cuaHang));
      return;
    }
    final ds = await cuaHang.khoiPhuc();
    QuyenLoi? tot;
    LoiMua? loi;
    for (final g in ds) {
      final kq = await _xacMinh(g, imLang: true);
      if (kq?.quyenLoi case final q? when q.pro) tot = q;
      loi ??= kq?.loi;
    }
    if (tot != null) {
      _phat(XacMinhXong(tot));
    } else if (loi != null) {
      _phat(XacMinhLoi(loi));
    } else {
      _phat(const KhoiPhucXong(thayGiaoDich: false));
    }
  }

  void boLoi() => _phat(const BoLoi());

  Future<void> _xuLy(List<GiaoDich> ds) async {
    for (final g in ds) {
      switch (g.loai) {
        case LoaiGiaoDich.choThanhToan:
          _phat(const ChoThanhToan());
        case LoaiGiaoDich.huy:
          _phat(const NguoiDungHuy());
        case LoaiGiaoDich.loi:
          _phat(const MoMuaLoi());
        case LoaiGiaoDich.daMua:
        case LoaiGiaoDich.khoiPhuc:
          await _xacMinh(g);
      }
    }
  }

  /// Gửi máy chủ; thành công -> lưu quyền lợi + hoàn tất với Play. [imLang]:
  /// không đổi trạng thái màn (khôi phục / thử lại nền tự tổng hợp).
  Future<KetQuaXacMinh?> _xacMinh(GiaoDich g, {bool imLang = false}) async {
    final sp = g.sanPham;
    if (sp == null || g.token.isEmpty || !_dangXacMinh.add(g.token)) {
      return null;
    }
    try {
      if (!imLang) _phat(const BatDauXacMinh());
      final kq = await xacMinh(sp, g.token);
      if (kq.quyenLoi case final q?) {
        await capNhatTuMayChu(q);
        await cuaHang.hoanTat(g);
        if (!imLang) _phat(XacMinhXong(q));
      } else if (!imLang) {
        _phat(XacMinhLoi(kq.loi ?? LoiMua.mayChu));
      }
      return kq;
    } finally {
      _dangXacMinh.remove(g.token);
    }
  }

  @override
  void dispose() {
    _dong = true;
    unawaited(_nghe?.cancel());
    super.dispose();
  }
}
