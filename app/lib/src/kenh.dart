import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:la_ban/src/cong_truc_tuyen.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:network/network.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';

/// Kênh app <-> API (S3, SEC-NET): Remote Config ký số (cập nhật bắt buộc /
/// khuyến nghị, kill-switch, pin CA), client API GHIM CA cho mọi yêu cầu có
/// phiên, và tình trạng thiết bị từ `/v1/status`.
final class KenhApp extends ChangeNotifier {
  new _(this.cauHinh, this.apiGhim, this._ghim);

  /// [kho] = thư mục dữ liệu app (gói Remote Config đã ký lưu ở
  /// `cau_hinh_tu_xa.json`). Flavor dev (`http://`) không ghim.
  factory tao(Flavor flavor, KhoLuuTru kho) {
    late final KenhApp k;
    final ch = DichVuCauHinh(
      // Kho CA hệ thống: gói tự mang chữ ký Ed25519 nên tải không cần ghim -
      // nhờ vậy xoay pin được cả khi CA của API đổi bất ngờ.
      api: ApiClientIo(flavor.apiGoc),
      kho: KhoGoiTep(TepJson.mo('${kho.thuMuc}/cau_hinh_tu_xa.json')),
      khoa: khoaCauHinhApp,
      khiDoi: (_) => k._apDung(),
    );
    final ghim = flavor.apiGoc.scheme == 'https' ? ch.gocTinCay : null;
    return k = KenhApp._(ch, ApiClientIo(flavor.apiGoc, gocGhim: ghim), ghim);
  }

  final DichVuCauHinh cauHinh;

  /// Client cho định danh + yêu cầu ký: chỉ tin CA trong bộ ghim.
  final ApiClientIo apiGhim;
  List<String>? _ghim;
  TinhTrangThietBi? _tinhTrang;

  /// Tình trạng gần nhất từ `/v1/status` (null = chưa có / offline).
  TinhTrangThietBi? get tinhTrang => _tinhTrang;

  /// Đổi bộ ghim khi Remote Config đổi / hết hạn.
  void _apDung() {
    final ghim = _ghim;
    final moi = cauHinh.gocTinCay;
    if (ghim != null && !_cungDs(ghim, moi)) {
      apiGhim.doiGhim(moi);
      _ghim = moi;
    }
    notifyListeners();
  }

  static bool _cungDs(List<String> a, List<String> b) =>
      a.length == b.length && a.every(b.contains);

  /// Tải Remote Config rồi hỏi tình trạng thiết bị (cần phiên). Lỗi mạng bỏ
  /// qua: app chạy tiếp với cấu hình đang có.
  /// [phatTrien]: trạng thái Developer options gửi kèm (`pt`, S11).
  Future<void> lamMoi(
    DichVuDinhDanh? dinhDanh, {
    TrangThaiPhatTrien? phatTrien,
  }) async {
    await cauHinh.lamMoi();
    _apDung();
    if (dinhDanh == null) return;
    if (await dinhDanh.tinhTrang(phatTrien: phatTrien) case Ok(:final value)) {
      _tinhTrang = value;
      notifyListeners();
    }
  }

  /// Người dùng vừa tắt Developer options: bỏ cờ chặn của phản hồi CŨ để màn
  /// chặn không treo trong lúc chờ `/v1/status` mới (server vẫn chặn API tới
  /// khi nhận `pt=0`).
  void boChanMayChu() {
    final t = _tinhTrang;
    if (t == null || !t.cheDoPhatTrien) return;
    _tinhTrang = t.voiPhatTrien(chan: false);
    notifyListeners();
  }
}

/// Gói Remote Config nguyên văn trong `cau_hinh_tu_xa.json`.
final class KhoGoiTep implements KhoGoiCauHinh {
  new(this._t);

  final TepJson _t;

  @override
  String? doc() => _t.duLieu['goi'] as String?;

  @override
  Future<void> ghi(String goi) => _t.ghi({'goi': goi});
}

/// Kênh của lần chạy (null: chế độ an toàn / test không bật mạng).
final kenhProvider = Provider<KenhApp?>((_) => null);

T? _theoKenh<T>(Ref ref, T? Function(KenhApp k) lay) {
  final k = ref.watch(kenhProvider);
  if (k == null) return null;
  void doi() => ref.invalidateSelf();
  k.addListener(doi);
  ref.onDispose(() => k.removeListener(doi));
  return lay(k);
}

/// Remote Config đang hiệu lực (null = mặc định đóng gói).
final cauHinhTuXaProvider = Provider<CauHinhTuXa?>(
  (ref) => _theoKenh(ref, (k) => k.cauHinh.hienTai),
);

/// Tình trạng thiết bị gần nhất (S4 dùng cho màn khoá theo Risk Level).
final tinhTrangProvider = Provider<TinhTrangThietBi?>(
  (ref) => _theoKenh(ref, (k) => k.tinhTrang),
);

/// Tải Remote Config + tình trạng ở nền sau khung đầu, và mỗi lần app quay
/// lại foreground (cách nhau >= [khoang]) - chỉ khi [cong] mở.
void batDauKenh(
  KenhApp k,
  DichVuDinhDanh? dinhDanh,
  CongTrucTuyen cong, {
  Duration cho = const Duration(seconds: 3),
  Duration khoang = const Duration(minutes: 15),
  TrangThaiPhatTrien Function()? phatTrien,
}) {
  DateTime? lanCuoi;
  void chay() {
    if (!cong.value) return;
    final bayGio = DateTime.now();
    if (lanCuoi != null && bayGio.difference(lanCuoi!) < khoang) return;
    lanCuoi = bayGio;
    unawaited(k.lamMoi(dinhDanh, phatTrien: phatTrien?.call()));
  }

  WidgetsBinding.instance.addPostFrameCallback(
    (_) => Timer(
      cho,
      () => cong.khiMo(() {
        chay();
        AppLifecycleListener(onResume: chay);
      }),
    ),
  );
}
