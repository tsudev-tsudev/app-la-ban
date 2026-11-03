import 'dart:math' as math;

import 'package:sensors/src/domain/do_tin_cay.dart';
import 'package:sensors/src/domain/goc_vong.dart';
import 'package:sensors/src/domain/madgwick.dart';
import 'package:sensors/src/domain/mau_cam_bien.dart';
import 'package:sensors/src/domain/quat.dart';
import 'package:sensors/src/domain/thien_van.dart';
import 'package:sensors/src/domain/tu_the.dart';

// A9a (QUYET_DINH Q59): máy thiếu từ kế / cảm biến vẫn có hướng, theo chuỗi
// nguồn có thứ tự + độ tin cậy. Toàn bộ là hàm / lớp THUẦN (không I/O, không
// đồng hồ thật) - provider ở `providers.dart` nối dữ liệu thật vào.

/// Nguồn hướng, theo thứ tự ưu tiên.
enum NguonChiHuong {
  /// Từ kế (fusion A2) - nguồn chính.
  tuKe,

  /// Hướng di chuyển GPS (course) khi đi >= ~1 m/s.
  gps,

  /// Neo theo Mặt Trời (ngắm thẳng hoặc theo bóng).
  matTroi,

  /// Neo theo Mặt Trăng (ngắm thẳng).
  matTrang,

  /// Người dùng tự đặt hướng (theo mốc đã biết / xoay tay).
  thuCong,
}

/// Một ước lượng hướng. `phuongVi` là hướng mép trên máy, độ [0, 360).
typedef HuongUocLuong = ({
  double phuongVi,

  /// true: bắc thực; false: bắc từ (từ kế khi chưa có độ lệch WMM).
  bool bacThuc,
  NguonChiHuong nguon,

  /// Sai số ước lượng (độ, ~68%).
  double saiSoDo,

  /// Con quay đang giữ hướng sau khi neo theo `nguon` (không đo trực tiếp).
  bool theoConQuay,
});

/// Năng lực thiết bị dò MỘT lần (không định danh phần cứng - chỉ có / không).
typedef NangLucThietBi = ({
  bool tuKe,
  bool conQuay,
  bool giaToc,

  /// `TYPE_GAME_ROTATION_VECTOR` (con quay + gia tốc do hệ điều hành hợp nhất).
  bool xoayGame,
  bool khiAp,
  bool gps,
  bool camera,
});

NangLucThietBi nangLucTu(
  KhaNangCamBien k, {
  required bool gps,
  required bool camera,
}) => (
  tuKe: k.tu || k.xoayVector,
  conQuay: k.conQuay,
  giaToc: k.giaToc,
  xoayGame: k.xoayGame,
  khiAp: k.apSuat,
  gps: gps,
  camera: camera,
);

/// Có giữ được hướng TƯƠNG ĐỐI (xoay máy thì kim xoay theo) không cần từ kế.
bool giuHuongDuoc(NangLucThietBi n) => n.xoayGame || (n.conQuay && n.giaToc);

/// Các nguồn dùng được trên máy này, theo thứ tự ưu tiên. Mặt Trời / Mặt
/// Trăng / thủ công không cần cảm biến (theo bóng, đặt tay).
List<NguonChiHuong> nguonKhaDung(NangLucThietBi n) => [
  if (n.tuKe) NguonChiHuong.tuKe,
  if (n.gps) NguonChiHuong.gps,
  NguonChiHuong.matTroi,
  NguonChiHuong.matTrang,
  NguonChiHuong.thuCong,
];

/// Máy cũ / yếu -> chế độ nhẹ (giảm tần số vẽ, tắt hiệu ứng nặng): ít nhân
/// CPU hoặc không có con quay (dấu hiệu máy rẻ). [soNhan] =
/// `Platform.numberOfProcessors`. Không dò được gì (không báo cả gia tốc kế -
/// nền tảng chưa hỗ trợ / test) thì không đoán là yếu.
bool mayYeu(NangLucThietBi n, {required int soNhan}) =>
    n.giaToc && (soNhan <= 4 || !n.conQuay);

/// Sai số (độ) của từ kế theo mức tin cậy A2.
double saiSoTuKe(MucTinCay muc, {required bool nhieuTu}) => nhieuTu
    ? 45
    : switch (muc) {
        MucTinCay.cao => 3,
        MucTinCay.trungBinh => 8,
        MucTinCay.thap => 20,
      };

// ---------------------------------------------------------------- GPS

/// Một lần đọc GPS dùng cho hướng di chuyển.
typedef ChuyenDongGps = ({
  double viDo,
  double kinhDo,

  /// m/s; null khi máy không báo.
  double? tocDo,

  /// Hướng di chuyển (độ, bắc thực).
  double? huongDi,
  double? saiSoTocDo,
  double? saiSoHuongDi,
  DateTime luc,
});

/// Hướng từ GPS course: chỉ tin khi đi đủ nhanh, hướng ổn định và vệt đủ
/// dài. Đứng lại / đổi hướng gắt -> bắt đầu vệt mới.
final class TheoDoiHuongGps {
  new({
    this.tocDoToiThieu = 1.0,
    this.vetToiThieuM = 10,
    this.saiSoToiDa = 45,
    this.cuToiDa = const Duration(seconds: 5),
  });

  final double tocDoToiThieu;
  final double vetToiThieuM;
  final double saiSoToiDa;

  /// Hai lần đọc cách nhau quá lâu -> vệt đứt.
  final Duration cuToiDa;

  ChuyenDongGps? _truoc;
  double _vetM = 0;

  double get doDaiVetM => _vetM;

  void datLai() {
    _truoc = null;
    _vetM = 0;
  }

  /// Nạp một lần đọc; trả ước lượng (bắc thực) hoặc null khi chưa tin được.
  HuongUocLuong? nap(ChuyenDongGps g) {
    final v = g.tocDo;
    final h = g.huongDi;
    if (v == null || h == null || v < tocDoToiThieu) {
      datLai();
      return null;
    }
    final t = _truoc;
    if (t != null &&
        t.huongDi != null &&
        g.luc.difference(t.luc) <= cuToiDa &&
        hieuGoc(h, t.huongDi!).abs() < 45) {
      _vetM += khoangCachGanDungM(t.viDo, t.kinhDo, g.viDo, g.kinhDo);
    } else {
      _vetM = 0;
    }
    _truoc = g;
    final goc =
        g.saiSoHuongDi ??
        (g.saiSoTocDo == null
            ? 20.0
            : radSangDo(math.atan2(g.saiSoTocDo!, v)).clamp(2.0, 90.0));
    final saiSo = goc + (_vetM < vetToiThieuM ? 10 : 0);
    if (_vetM < vetToiThieuM / 2 || saiSo > saiSoToiDa) return null;
    return (
      phuongVi: chuanHoaDo(h),
      bacThuc: true,
      nguon: NguonChiHuong.gps,
      saiSoDo: saiSo,
      theoConQuay: false,
    );
  }
}

/// Khoảng cách gần đúng (m) giữa hai điểm gần nhau (phẳng cục bộ).
double khoangCachGanDungM(double vi1, double kinh1, double vi2, double kinh2) {
  const mMoiDo = 111320.0;
  final dy = (vi2 - vi1) * mMoiDo;
  final dx = (kinh2 - kinh1) * mMoiDo * math.cos(vi1 * math.pi / 180);
  return math.sqrt(dx * dx + dy * dy);
}

// ---------------------------------------------------------------- Thiên thể

/// Hướng (bắc thực) của mép trên máy khi người dùng căn theo thiên thể:
/// - ngắm thẳng: mép trên chĩa về thiên thể (Mặt Trăng; KHÔNG nhìn Mặt Trời);
/// - theo bóng ([theoBong]): đặt máy dọc bóng của một vật thẳng đứng, mép
///   trên hướng ra xa gốc vật -> ngược phương vị Mặt Trời.
/// null khi thiên thể quá thấp (dưới [doCaoToiThieu]) hoặc quá gần thiên đỉnh
/// khi theo bóng (bóng quá ngắn, phương vị không xác định).
HuongUocLuong? huongTuThienThe(
  ViTriBauTroi tt, {
  required NguonChiHuong nguon,
  required bool theoBong,
  double doCaoToiThieu = 3,
}) {
  if (tt.doCao < doCaoToiThieu) return null;
  if (theoBong && tt.doCao > 80) return null;
  // Căn tay ~5°; bóng ngắn dần khi thiên thể lên cao -> căn kém chính xác.
  final saiSo = 5.0 + (theoBong && tt.doCao > 60 ? (tt.doCao - 60) / 2 : 0);
  return (
    phuongVi: chuanHoaDo(theoBong ? tt.phuongVi + 180 : tt.phuongVi),
    bacThuc: true,
    nguon: nguon,
    saiSoDo: saiSo,
    theoConQuay: false,
  );
}

// ------------------------------------------------------- Neo + con quay

/// Mốc neo: tại lúc neo, hướng thật là `goc.phuongVi` khi hướng tương đối
/// (con quay) là `phuongViTuongDoi`. Sau đó hướng = tương đối + lệch,
/// sai số tăng theo trôi con quay. Máy không giữ được hướng tương đối
/// ([tinh] = true): hướng cố định - người dùng giữ máy đúng tư thế đã căn.
final class NeoHuong {
  const new({
    required this.lech,
    required this.goc,
    required this.tNs,
    this.tinh = false,
    this.troiDoMoiPhut = 1.0,
  });

  /// Tạo neo từ ước lượng [goc] và hướng tương đối lúc đó.
  factory tu(
    HuongUocLuong goc, {
    required double phuongViTuongDoi,
    required int tNs,
    bool tinh = false,
    double troiDoMoiPhut = 1.0,
  }) => NeoHuong(
    lech: chuanHoaDo(goc.phuongVi - phuongViTuongDoi),
    goc: goc,
    tNs: tNs,
    tinh: tinh,
    troiDoMoiPhut: troiDoMoiPhut,
  );

  /// hướng thật - hướng tương đối (độ).
  final double lech;

  /// Ước lượng dùng để neo (nguồn + sai số lúc neo).
  final HuongUocLuong goc;

  /// Mốc thời gian neo (ns, cùng đồng hồ với mẫu cảm biến).
  final int tNs;
  final bool tinh;

  /// Trôi con quay ước lượng (độ / phút) - bảo thủ cho máy rẻ.
  final double troiDoMoiPhut;

  /// Sai số hiện tại sau [tNsHienTai].
  double saiSoLuc(int tNsHienTai) {
    if (tinh) return goc.saiSoDo;
    final phut = math.max(0, tNsHienTai - tNs) / 6e10;
    return goc.saiSoDo + troiDoMoiPhut * phut;
  }

  /// Quá sai số này thì nhắc neo lại.
  static const saiSoNhacNeoLai = 15.0;

  bool canNeoLai(int tNsHienTai) => saiSoLuc(tNsHienTai) > saiSoNhacNeoLai;

  HuongUocLuong uocLuong(double phuongViTuongDoi, int tNsHienTai) => (
    phuongVi: chuanHoaDo((tinh ? 0 : phuongViTuongDoi) + lech),
    bacThuc: goc.bacThuc,
    nguon: goc.nguon,
    saiSoDo: saiSoLuc(tNsHienTai),
    theoConQuay: !tinh,
  );
}

// ---------------------------------------------------------------- Chọn nguồn

/// Chọn nguồn theo thứ tự từ kế > GPS > neo (Mặt Trời / Mặt Trăng / thủ công
/// + con quay). Nguồn đứng trước bị bỏ qua khi nguồn sau tốt hơn hẳn (sai số
/// nhỏ hơn một nửa) - vd từ kế đang nhiễu nặng mà đang đi nhanh có GPS.
HuongUocLuong? chonHuong({
  HuongUocLuong? tuKe,
  HuongUocLuong? gps,
  HuongUocLuong? neo,
}) {
  HuongUocLuong? chon;
  for (final u in [tuKe, gps, neo]) {
    if (u == null) continue;
    if (chon == null || u.saiSoDo < chon.saiSoDo / 2) chon = u;
  }
  return chon;
}

// ------------------------------------------------------- Hướng tương đối

/// Hướng TƯƠNG ĐỐI không cần từ kế: game rotation vector của hệ điều hành
/// nếu có, không thì Madgwick trên con quay + gia tốc (mốc phương vị tuỳ ý
/// lúc bắt đầu). Bỏ qua mọi mẫu từ trường. Dùng cùng [NeoHuong].
final class BoHuongTuongDoi {
  new({Madgwick? madgwick}) : _madgwick = madgwick ?? Madgwick();

  final Madgwick _madgwick;
  Vec3? _giaToc;
  XoayManHinh _xoay = XoayManHinh.r0;
  var _coXoayGame = false;
  var _san = false;
  int? _tTruoc;

  static const _khoangTrongDatLai = 0.5;

  /// Nạp một mẫu; trả (phương vị tương đối, tNs) khi có nhịp mới.
  ({double phuongVi, int tNs})? nap(MauCamBien m) {
    switch (m.loai) {
      case LoaiMau.giaToc:
        _giaToc = Vec3(m.x, m.y, m.z);
        return null;
      case LoaiMau.xoayManHinh:
        _xoay = XoayManHinh.values[m.x.toInt().clamp(0, 3)];
        return null;
      case LoaiMau.xoayGame:
        _coXoayGame = true;
        final q = quatTuVectorQuay(m.x, m.y, m.z, m.w);
        return (phuongVi: tuTheTuQuat(q, xoay: _xoay).phuongVi, tNs: m.tNs);
      case LoaiMau.conQuay:
        if (_coXoayGame) return null;
        return _buocConQuay(m);
      case LoaiMau.tu || LoaiMau.xoayVector || LoaiMau.apSuat:
        return null;
    }
  }

  ({double phuongVi, int tNs})? _buocConQuay(MauCamBien m) {
    final a = _giaToc;
    if (a == null) return null;
    final truoc = _tTruoc;
    _tTruoc = m.tNs;
    final dt = truoc == null ? 0.0 : (m.tNs - truoc) / 1e9;
    if (!_san || dt > _khoangTrongDatLai || dt < 0) {
      // Không có từ trường: "bắc giả" = trục máy ít song song trọng lực nhất.
      final q0 = quatTuGiaTocTu(a, _trucGiaBac(a));
      if (q0 == null) return null;
      _madgwick.datLai(q0);
      _san = true;
    } else {
      _madgwick.capNhat(Vec3(m.x, m.y, m.z), a, null, dt);
    }
    final pv = tuTheTuQuat(_madgwick.tuThe, xoay: _xoay).phuongVi;
    return (phuongVi: pv, tNs: m.tNs);
  }

  static Vec3 _trucGiaBac(Vec3 a) {
    final ay = a.y.abs();
    final az = a.z.abs();
    return ay <= az ? const Vec3(0, 1, 0) : const Vec3(0, 0, -1);
  }
}
