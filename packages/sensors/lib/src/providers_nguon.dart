import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors/src/domain/goc_vong.dart';
import 'package:sensors/src/domain/mau_cam_bien.dart';
import 'package:sensors/src/domain/nguon_chi_huong.dart';
import 'package:sensors/src/domain/thien_van.dart';
import 'package:sensors/src/providers.dart';

// A9a (Q59): chuỗi nguồn hướng cho máy thiếu phần cứng. Nối dữ liệu thật vào
// domain thuần `nguon_chi_huong.dart`. Tính năng (la bàn, dẫn đường) chỉ đọc
// `huongDaNguonProvider`; location_feature đẩy GPS vào
// `chuyenDongGpsProvider` như đã đẩy vị trí.

/// Bảng khả năng cảm biến (dò một lần).
final FutureProvider<KhaNangCamBien> khaNangCamBienProvider = FutureProvider(
  (ref) => ref.watch(nguonCamBienProvider).khaNang(),
);

/// Máy có GPS / camera sau. Gần như mọi điện thoại đều có; app override khi
/// cần (test, máy tính bảng không GPS).
final coGpsProvider = Provider<bool>((_) => true);
final coCameraProvider = Provider<bool>((_) => true);

/// Số nhân CPU (test override).
final soNhanProvider = Provider<int>((_) => Platform.numberOfProcessors);

/// Năng lực thiết bị; null khi đang dò.
final Provider<NangLucThietBi?> nangLucProvider = Provider((ref) {
  final k = ref.watch(khaNangCamBienProvider).value;
  if (k == null) return null;
  return nangLucTu(
    k,
    gps: ref.watch(coGpsProvider),
    camera: ref.watch(coCameraProvider),
  );
});

/// Chế độ nhẹ cho máy cũ / yếu (giảm tần số vẽ, tắt hiệu ứng nặng).
final Provider<bool> cheDoNheProvider = Provider((ref) {
  final n = ref.watch(nangLucProvider);
  return n != null && mayYeu(n, soNhan: ref.watch(soNhanProvider));
});

/// Lần đọc GPS mới nhất (location_feature đẩy vào); null khi chưa có.
final chuyenDongGpsProvider =
    NotifierProvider<ChuyenDongGpsNotifier, ChuyenDongGps?>(
      ChuyenDongGpsNotifier.new,
    );

class ChuyenDongGpsNotifier extends Notifier<ChuyenDongGps?> {
  @override
  ChuyenDongGps? build() => null;

  // ignore: use_setters_to_change_properties - API nạp dữ liệu, không phải thuộc tính.
  void nap(ChuyenDongGps g) => state = g;
}

/// Hướng di chuyển GPS đã lọc (vệt đủ dài, đủ nhanh); null khi chưa tin.
final Provider<HuongUocLuong?> huongGpsProvider = Provider((ref) {
  final theo = ref.watch(_theoDoiGpsProvider);
  final g = ref.watch(chuyenDongGpsProvider);
  return g == null ? null : theo.nap(g);
});

final _theoDoiGpsProvider = Provider<TheoDoiHuongGps>((_) => TheoDoiHuongGps());

/// Hướng TƯƠNG ĐỐI (con quay) - chỉ chạy khi có màn đang cần (autoDispose).
final StreamProvider<({double phuongVi, int tNs})> huongTuongDoiProvider =
    StreamProvider.autoDispose(
      (ref) => ref.watch(dichVuHuongProvider).theoDoiTuongDoi(),
      retry: (_, _) => null,
    );

/// Mốc neo hiện tại (Mặt Trời / Mặt Trăng / thủ công / GPS); null khi chưa.
final neoHuongProvider = NotifierProvider<NeoHuongNotifier, NeoHuong?>(
  NeoHuongNotifier.new,
);

class NeoHuongNotifier extends Notifier<NeoHuong?> {
  @override
  NeoHuong? build() {
    // Đang đi có GPS tốt -> tự neo lại con quay theo GPS, để khi dừng lại
    // vẫn giữ hướng (A9a: GPS > thiên thể > con quay neo).
    // Chỉ khi máy không có từ kế: máy có từ kế không cần (và không bật luồng
    // con quay thứ hai).
    ref.listen(huongGpsProvider, (_, g) {
      if (g != null &&
          ref.read(coTuKeProvider) == false &&
          _tuongDoi() != null) {
        neo(g);
      }
    });
    return null;
  }

  ({double phuongVi, int tNs})? _tuongDoi() =>
      ref.read(huongTuongDoiProvider).value;

  /// Neo theo [goc]. Không có hướng tương đối -> neo tĩnh.
  void neo(HuongUocLuong goc) {
    final t = _tuongDoi();
    state = NeoHuong.tu(
      goc,
      phuongViTuongDoi: t?.phuongVi ?? 0,
      tNs: t?.tNs ?? 0,
      tinh: t == null,
    );
  }

  /// Neo theo Mặt Trời (theo bóng) / Mặt Trăng (ngắm thẳng) tại vị trí và
  /// giờ hiện tại. Trả false khi thiên thể không dùng được (dưới chân trời,
  /// bóng quá ngắn, chưa có vị trí).
  bool neoThienThe({required bool matTrang, bool theoBong = true}) {
    final v = ref.read(viTriProvider);
    if (v == null) return false;
    final luc = ref.read(dongHoProvider)();
    final tt = matTrang
        ? viTriMatTrang(luc, v.viDo, v.kinhDo)
        : viTriMatTroi(luc, v.viDo, v.kinhDo);
    final u = huongTuThienThe(
      tt,
      nguon: matTrang ? NguonChiHuong.matTrang : NguonChiHuong.matTroi,
      theoBong: !matTrang && theoBong,
    );
    if (u == null) return false;
    neo(u);
    return true;
  }

  /// Người dùng tự đặt: mép trên máy đang chỉ [phuongVi] (bắc thực).
  void neoThuCong(double phuongVi) => neo((
    phuongVi: chuanHoaDo(phuongVi),
    bacThuc: true,
    nguon: NguonChiHuong.thuCong,
    saiSoDo: 10,
    theoConQuay: false,
  ));

  void xoa() => state = null;
}

/// Thiên thể nào đang dùng được để neo lúc này (độ cao đủ, có vị trí).
final Provider<({bool matTroi, bool matTrang})> thienTheDungDuocProvider =
    Provider((ref) {
      final v = ref.watch(viTriProvider);
      if (v == null) return (matTroi: false, matTrang: false);
      final luc = ref.watch(dongHoProvider)();
      HuongUocLuong? thu(ViTriBauTroi tt, {required bool bong}) =>
          huongTuThienThe(tt, nguon: NguonChiHuong.thuCong, theoBong: bong);
      return (
        matTroi: thu(viTriMatTroi(luc, v.viDo, v.kinhDo), bong: true) != null,
        matTrang:
            thu(viTriMatTrang(luc, v.viDo, v.kinhDo), bong: false) != null,
      );
    });

/// Hướng tốt nhất theo chuỗi nguồn: từ kế > GPS > neo (+ con quay). null khi
/// chưa có nguồn nào (máy không la bàn, đứng yên, chưa neo).
final Provider<HuongUocLuong?> huongDaNguonProvider = Provider((ref) {
  HuongUocLuong? tuKe;
  final h = ref.watch(huongProvider).value;
  if (h != null) {
    final lech = ref.watch(tuTruongProvider)?.doLech;
    tuKe = (
      phuongVi: chuanHoaDo(h.phuongVi + (lech ?? 0)),
      bacThuc: lech != null,
      nguon: NguonChiHuong.tuKe,
      saiSoDo: saiSoTuKe(h.muc, nhieuTu: h.nhieuTu),
      theoConQuay: false,
    );
  }
  final gps = ref.watch(huongGpsProvider);
  final neo = ref.watch(neoHuongProvider);
  // Máy không từ kế: giữ luồng con quay chạy (để neo có mốc tương đối).
  final t = ref.watch(coTuKeProvider) == false
      ? ref.watch(huongTuongDoiProvider).value
      : null;
  HuongUocLuong? quaNeo;
  if (neo != null) {
    quaNeo = neo.tinh
        ? neo.uocLuong(0, 0)
        : t == null
        ? null
        : neo.uocLuong(t.phuongVi, t.tNs);
  }
  return chonHuong(tuKe: tuKe, gps: gps, neo: quaNeo);
});

/// Máy có từ kế (đã dò xong và có). null khi đang dò.
final Provider<bool?> coTuKeProvider = Provider(
  (ref) => ref.watch(nangLucProvider)?.tuKe,
);

/// Đã neo mà sai số trôi quá ngưỡng -> nhắc neo lại.
final Provider<bool> canNeoLaiProvider = Provider((ref) {
  final n = ref.watch(neoHuongProvider);
  if (n == null || n.tinh) return false;
  final t = ref.watch(huongTuongDoiProvider).value;
  return t != null && n.canNeoLai(t.tNs);
});
