import 'package:sensors/src/domain/do_tin_cay.dart';
import 'package:sensors/src/domain/goc_vong.dart';
import 'package:sensors/src/domain/loc_goc.dart';
import 'package:sensors/src/domain/madgwick.dart';
import 'package:sensors/src/domain/mau_cam_bien.dart';
import 'package:sensors/src/domain/quat.dart';
import 'package:sensors/src/domain/tu_the.dart';

/// Nguồn tư thế đang dùng.
enum NguonHuong {
  /// Madgwick của app trên con quay + gia tốc + từ (mặc định khi đủ cảm biến).
  madgwick,

  /// `TYPE_ROTATION_VECTOR` do hệ điều hành hợp nhất (máy không con quay).
  heThong,

  /// Bù nghiêng gia tốc + từ, không con quay (máy rẻ nhất).
  giaTocTu,
}

/// Một lần đọc hướng đã hợp nhất + lọc, sẵn sàng hiển thị.
final class HuongDoc {
  const new({
    required this.phuongVi,
    required this.phuongViTho,
    required this.doc,
    required this.lan,
    required this.theoCamera,
    required this.muc,
    required this.nhieuTu,
    required this.canHieuChuan,
    required this.cuongDoTu,
    required this.nguon,
    required this.dungYen,
    required this.tNs,
    this.apSuat,
  });

  /// Phương vị từ đã lọc [0, 360) (bắc từ; bắc thực cộng độ lệch WMM ở A3).
  final double phuongVi;

  /// Phương vị từ trước bộ lọc (để chẩn đoán).
  final double phuongViTho;

  /// Góc ngóc / nghiêng ngang theo màn hình (độ).
  final double doc;
  final double lan;

  /// Máy dựng đứng -> phương vị theo hướng camera sau.
  final bool theoCamera;
  final MucTinCay muc;
  final bool nhieuTu;
  final bool canHieuChuan;

  /// Cường độ từ trường (µT), NaN khi chưa có.
  final double cuongDoTu;
  final NguonHuong nguon;

  /// Máy đứng yên (nền tảng có thể hạ tần số lấy mẫu).
  final bool dungYen;

  /// Áp suất khí quyển (hPa) nếu máy có khí áp kế.
  final double? apSuat;
  final int tNs;
}

/// Bộ hợp nhất cảm biến THUẦN (không I/O, không đồng hồ thật): nạp mẫu theo
/// thứ tự thời gian, nhận [HuongDoc] mỗi khi có mẫu "nhịp" (con quay với
/// Madgwick, vectơ quay với hệ thống, từ trường với bù nghiêng).
final class BoHopNhat {
  /// [uuTienHeThong]: dùng `TYPE_ROTATION_VECTOR` kể cả khi có con quay.
  new({
    this.uuTienHeThong = false,
    Madgwick? madgwick,
    KalmanGoc? kalman,
    LocThichUng? loc,
  }) : _madgwick = madgwick ?? Madgwick(),
       _kalman = kalman ?? KalmanGoc(),
       _loc = loc ?? LocThichUng();

  final bool uuTienHeThong;
  final Madgwick _madgwick;
  final KalmanGoc _kalman;
  final LocThichUng _loc;
  final TheoDoiNhieuTu _nhieu = TheoDoiNhieuTu();
  final PhatHienDungYen _dungYen = PhatHienDungYen();
  final CuaSoVong _rung = CuaSoVong(50);

  Vec3? _giaToc;
  Vec3? _tu;
  Quat? _xoayHeThong;
  DoChinhXacOs _osTu = DoChinhXacOs.trungBinh;
  XoayManHinh _xoay = XoayManHinh.r0;
  var _coConQuay = false;
  var _nhieuTuHienTai = false;
  var _madgwickSan = false;
  double? _apSuat;
  int? _tTruoc;

  /// Khoảng trống giữa hai mẫu (s) coi là vừa tiếp tục sau tạm dừng ->
  /// khởi tạo lại.
  static const _khoangTrongDatLai = 0.5;

  NguonHuong get nguon {
    if (_coConQuay && !(uuTienHeThong && _xoayHeThong != null)) {
      return NguonHuong.madgwick;
    }
    if (_xoayHeThong != null) return NguonHuong.heThong;
    return NguonHuong.giaTocTu;
  }

  HuongDoc? nap(MauCamBien m) {
    switch (m.loai) {
      case LoaiMau.giaToc:
        _giaToc = Vec3(m.x, m.y, m.z);
        return null;
      case LoaiMau.apSuat:
        _apSuat = m.x;
        return null;
      case LoaiMau.xoayManHinh:
        _xoay = XoayManHinh.values[m.x.toInt().clamp(0, 3)];
        return null;
      case LoaiMau.xoayGame:
        return null;
      case LoaiMau.tu:
        final v = Vec3(m.x, m.y, m.z);
        _tu = v;
        _osTu = DoChinhXacOs.values[m.doChinhXac.clamp(0, 3)];
        _nhieuTuHienTai = _nhieu.nap(v.doDai);
        if (nguon != NguonHuong.giaTocTu) return null;
        final a = _giaToc;
        if (a == null) return null;
        final q = quatTuGiaTocTu(a, v);
        return q == null ? null : _xuat(q, m.tNs, null);
      case LoaiMau.xoayVector:
        final q = quatTuVectorQuay(m.x, m.y, m.z, m.w);
        _xoayHeThong = q;
        if (nguon != NguonHuong.heThong) return null;
        return _xuat(q, m.tNs, null);
      case LoaiMau.conQuay:
        _coConQuay = true;
        if (nguon != NguonHuong.madgwick) return null;
        return _buocMadgwick(m);
    }
  }

  HuongDoc? _buocMadgwick(MauCamBien m) {
    final a = _giaToc;
    final tu = _tu;
    if (a == null || tu == null) return null;
    final g = Vec3(m.x, m.y, m.z);
    final truoc = _tTruoc;
    final dt = truoc == null ? 0.0 : (m.tNs - truoc) / 1e9;
    if (!_madgwickSan || dt > _khoangTrongDatLai || dt < 0) {
      final q0 = quatTuGiaTocTu(a, tu);
      if (q0 == null) return null;
      _madgwick.datLai(q0);
      _madgwickSan = true;
      _kalman.datLai();
      _loc.datLai();
    } else {
      // Từ trường nhiễu -> chỉ con quay + gia tốc, giữ hướng đã có.
      _madgwick.capNhat(g, a, _nhieuTuHienTai ? null : tu, dt);
    }
    return _xuat(_madgwick.tuThe, m.tNs, g.doDai);
  }

  HuongDoc _xuat(Quat q, int tNs, double? omega) {
    final truoc = _tTruoc;
    _tTruoc = tNs;
    var dt = truoc == null ? 0.0 : (tNs - truoc) / 1e9;
    if (dt < 0 || dt > _khoangTrongDatLai) {
      dt = 0;
      _kalman.datLai();
      _loc.datLai();
      _rung.xoa();
    }
    final t = tuTheTuQuat(q, xoay: _xoay);
    if (omega != null) _dungYen.nap(omega, dt);
    _rung.them(t.phuongVi);
    final lechChuan = _dungYen.dungYen && _rung.soMau >= 25
        ? _rung.thongKe.doLechChuan
        : null;
    final tc = danhGiaTinCay(
      os: _osTu,
      nhieuTu: _nhieuTuHienTai,
      doLechChuan: lechChuan,
    );
    final phuongSai = switch (tc.muc) {
      MucTinCay.cao => 1.0,
      MucTinCay.trungBinh => 9.0,
      MucTinCay.thap => 36.0,
    };
    final k = _kalman.capNhat(t.phuongVi, dt, phuongSai: phuongSai);
    final huong = _loc.capNhat(k, dt, tocDo: _kalman.tocDo);
    return HuongDoc(
      phuongVi: huong,
      phuongViTho: t.phuongVi,
      doc: t.doc,
      lan: t.lan,
      theoCamera: t.theoCamera,
      muc: tc.muc,
      nhieuTu: tc.nhieuTu,
      canHieuChuan: tc.canHieuChuan,
      cuongDoTu: _tu?.doDai ?? double.nan,
      nguon: nguon,
      dungYen: _dungYen.dungYen,
      apSuat: _apSuat,
      tNs: tNs,
    );
  }
}
