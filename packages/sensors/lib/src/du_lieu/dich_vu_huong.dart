import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sensors/src/domain/bo_hop_nhat.dart';
import 'package:sensors/src/domain/mau_cam_bien.dart';
import 'package:sensors/src/domain/nguon_chi_huong.dart';
import 'package:sensors/src/du_lieu/nguon_cam_bien.dart';

/// Lý do không đọc được hướng.
enum LoiCamBien {
  /// Máy không có cảm biến từ trường lẫn vectơ quay (hoặc nền tảng chưa
  /// hỗ trợ).
  khongCoLaBan,
}

/// Ngoại lệ phát trên luồng [DichVuHuong.theoDoi].
final class NgoaiLeCamBien implements Exception {
  const new(this.loi);

  final LoiCamBien loi;

  @override
  String toString() => 'NgoaiLeCamBien(${loi.name})';
}

/// Nối [NguonCamBien] với [BoHopNhat]. Mặc định chạy bộ hợp nhất trong một
/// isolate riêng (Spec §4.1: xử lý cảm biến ngoài UI isolate); luồng UI chỉ
/// chuyển tiếp lô byte và nhận MỘT [HuongDoc] mỗi lô (~60 Hz).
final class DichVuHuong {
  new(this._nguon, {this.dungIsolate = true, this.uuTienHeThong = false});

  final NguonCamBien _nguon;

  /// false: hợp nhất ngay trên isolate hiện tại (widget test / fakeAsync).
  final bool dungIsolate;
  final bool uuTienHeThong;

  /// Luồng hướng; chỉ chạy cảm biến khi có người nghe. Huỷ nghe (app xuống
  /// nền, rời tab) -> tắt cảm biến + dừng isolate.
  Stream<HuongDoc> theoDoi() {
    late StreamController<HuongDoc> ra;
    StreamSubscription<Float64List>? nghe;
    _XuLy? xuLy;
    bool? dungYen;
    var daHuy = false;

    Future<void> batDau() async {
      final kn = await _nguon.khaNang();
      if (!kn.tu && !kn.xoayVector) {
        ra
          ..addError(const NgoaiLeCamBien(LoiCamBien.khongCoLaBan))
          ..close().ignore();
        return;
      }
      final x = dungIsolate
          ? await _XuLyIsolate.tao(uuTienHeThong: uuTienHeThong)
          : _XuLyTaiCho(BoHopNhat(uuTienHeThong: uuTienHeThong));
      if (daHuy) {
        x.dong();
        return;
      }
      xuLy = x;
      // Lô xử lý theo thứ tự; giữ tương lai cuối để đóng luồng SAU khi kết
      // quả cuối về (nguồn hữu hạn như dữ liệu ghi sẵn).
      var cuoi = Future<void>.value();
      nghe = _nguon.lo().listen(
        (lo) => cuoi = x.xuLy(lo).then((h) {
          if (h == null || ra.isClosed) return;
          ra.add(h);
          // Hạ / nâng tần số khi trạng thái đứng yên đổi.
          if (dungYen != h.dungYen) {
            final dau = dungYen == null;
            dungYen = h.dungYen;
            if (!dau || h.dungYen) {
              _nguon
                  .datChuKy(h.dungYen ? chuKyChamUs : chuKyNhanhUs)
                  .catchError((_) {})
                  .ignore();
            }
          }
        }),
        onError: ra.addError,
        onDone: () => cuoi.whenComplete(() => ra.close().ignore()).ignore(),
      );
    }

    ra = StreamController<HuongDoc>(
      onListen: () => batDau().catchError(ra.addError).ignore(),
      onCancel: () async {
        daHuy = true;
        await nghe?.cancel();
        xuLy?.dong();
      },
    );
    return ra.stream;
  }

  /// Hướng TƯƠNG ĐỐI không cần từ kế (A9a): game rotation vector hoặc con
  /// quay + gia tốc. Máy không giữ được hướng -> luồng đóng ngay, không lỗi.
  /// Xử lý tại chỗ (phép tính nhẹ hơn hợp nhất đầy đủ, không cần isolate).
  Stream<({double phuongVi, int tNs})> theoDoiTuongDoi() async* {
    final kn = await _nguon.khaNang();
    if (!(kn.xoayGame || (kn.conQuay && kn.giaToc))) return;
    final bo = BoHuongTuongDoi();
    final chuKy = kn.xoayGame ? chuKyChamUs : chuKyNhanhUs;
    await for (final lo in _nguon.lo(chuKyUs: chuKy)) {
      ({double phuongVi, int tNs})? cuoi;
      for (final m in giaiMaLo(lo)) {
        cuoi = bo.nap(m) ?? cuoi;
      }
      if (cuoi != null) yield cuoi;
    }
  }
}

sealed class _XuLy {
  /// Hợp nhất một lô; trả lần đọc cuối của lô (null nếu chưa đủ dữ liệu).
  Future<HuongDoc?> xuLy(Float64List lo);
  void dong();
}

HuongDoc? _xuLyLo(BoHopNhat bo, Float64List lo) {
  HuongDoc? cuoi;
  for (final m in giaiMaLo(lo)) {
    cuoi = bo.nap(m) ?? cuoi;
  }
  return cuoi;
}

final class _XuLyTaiCho extends _XuLy {
  new(this._bo);

  final BoHopNhat _bo;

  @override
  Future<HuongDoc?> xuLy(Float64List lo) async => _xuLyLo(_bo, lo);

  @override
  void dong() {}
}

/// Isolate sống suốt phiên theo dõi. Lô gửi theo thứ tự, kết quả về theo đúng
/// thứ tự đó (hàng đợi Completer).
final class _XuLyIsolate extends _XuLy {
  new(this._isolate, this._gui, this._nhan, this._cho);

  final Isolate _isolate;
  final SendPort _gui;
  final ReceivePort _nhan;
  final List<Completer<HuongDoc?>> _cho;

  static Future<_XuLyIsolate> tao({required bool uuTienHeThong}) async {
    final nhan = ReceivePort();
    final iso = await Isolate.spawn(_chayNen, (
      nhan.sendPort,
      uuTienHeThong,
    ), debugName: 'la_ban_cam_bien');
    final cong = Completer<SendPort>();
    final cho = <Completer<HuongDoc?>>[];
    nhan.listen((tin) {
      if (tin is SendPort) {
        cong.complete(tin);
      } else if (cho.isNotEmpty) {
        cho.removeAt(0).complete(tin as HuongDoc?);
      }
    });
    return _XuLyIsolate(iso, await cong.future, nhan, cho);
  }

  static void _chayNen((SendPort, bool) thamSo) {
    final (ve, uuTien) = thamSo;
    final bo = BoHopNhat(uuTienHeThong: uuTien);
    final den = ReceivePort();
    ve.send(den.sendPort);
    den.listen((lo) => ve.send(_xuLyLo(bo, lo as Float64List)));
  }

  @override
  Future<HuongDoc?> xuLy(Float64List lo) {
    final c = Completer<HuongDoc?>();
    _cho.add(c);
    _gui.send(lo);
    return c.future;
  }

  @override
  void dong() {
    _nhan.close();
    _isolate.kill(priority: Isolate.immediate);
    for (final c in _cho) {
      c.complete(null);
    }
    _cho.clear();
  }
}
