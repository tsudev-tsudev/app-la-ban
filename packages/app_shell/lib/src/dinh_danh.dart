import 'dart:async';

import 'package:app_shell/src/cong_truc_tuyen.dart';
import 'package:app_shell/src/flavor.dart';
import 'package:app_shell/src/phien_ban.dart';
import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network/network.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';

/// Dịch vụ định danh thiết bị (S2). null: không có kho lưu trữ (chế độ an
/// toàn) hoặc test không bật.
final dichVuDinhDanhProvider = Provider<DichVuDinhDanh?>((_) => null);

/// `0.1.0-beta.4+4` -> ('0.1.0-beta.4', 4).
({String ten, int build}) tachPhienBan(String pb) {
  final i = pb.indexOf('+');
  if (i < 0) return (ten: pb, build: 1);
  return (
    ten: pb.substring(0, i),
    build: int.tryParse(pb.substring(i + 1)) ?? 1,
  );
}

/// Nối `network` vào cổng của security_sdk (gói đó không phụ thuộc network).
final class ApiDinhDanhIo implements ApiDinhDanh {
  new(this._api);

  final ApiClient _api;

  @override
  Future<PhanHoiDinhDanh> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  }) async {
    try {
      final r = await _api.post(duongDan, body, bearer: bearer);
      return (status: r.status, duLieu: r.duLieu);
    } on LoiMang catch (e) {
      throw LoiKetNoi(e.lyDo);
    }
  }

  @override
  Future<PhanHoiKy> goiTho(
    String phuongThuc,
    String duongDan, {
    List<int>? than,
    Map<String, String> tieuDe = const {},
  }) async {
    try {
      final r = await _api.goi(
        phuongThuc,
        duongDan,
        than: than,
        tieuDe: tieuDe,
      );
      return (status: r.status, duLieu: r.duLieu, gioMayChu: r.gioMayChu);
    } on LoiMang catch (e) {
      throw LoiKetNoi(e.lyDo);
    }
  }
}

/// `dinh_danh.json` qua TepJson của storage.
final class KhoTrangThaiTep implements KhoTrangThai {
  new(this._t);

  final TepJson _t;

  @override
  Map<String, Object?> get duLieu => _t.duLieu;

  @override
  void ghiDongBo(Map<String, Object?> moi) => _t.ghiDongBo(moi);

  @override
  Future<void> ghi(Map<String, Object?> moi) => _t.ghi(moi);
}

/// [api]: client đã ghim CA (S3 - `KenhApp.apiGhim`).
DichVuDinhDanh taoDichVuDinhDanh(KhoLuuTru kho, ApiClient api) {
  final pb = tachPhienBan(phienBanApp);
  return DichVuDinhDanh(
    api: ApiDinhDanhIo(api),
    nenTang: const NenTangThietBiKenh(),
    tep: KhoTrangThaiTep(TepJson.mo('${kho.thuMuc}/dinh_danh.json')),
    cauHinh: CauHinhDinhDanh(
      soDuAnCloud: Flavor.soDuAnCloud,
      phienBanApp: pb.ten,
      build: pb.build,
      ngonNgu: () {
        final ma = WidgetsBinding.instance.platformDispatcher.locale
            .toLanguageTag();
        return ma.length > 16 ? ma.substring(0, 16) : ma;
      },
    ),
  );
}

/// Đăng ký / làm mới phiên ở nền sau khi app đã ổn định - không chặn khung
/// đầu, lỗi (offline, Google lỗi) không làm phiền người dùng: la bàn chạy đủ
/// khi không có mạng. Lỗi -> thử lại theo [LichThuLai]; mỗi lần app quay lại
/// foreground chạy lại (rẻ: phiên còn hạn thì không gọi mạng).
/// Chỉ chạy khi [cong] mở (người dùng đồng ý - Q43); đồng ý muộn -> chạy lúc
/// đó.
void batDauDinhDanh(
  DichVuDinhDanh dv,
  CongTrucTuyen cong, {
  Duration cho = const Duration(seconds: 3),
}) {
  final c = ChayDinhDanh(dv, duocChay: () => cong.value);
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => Timer(
      cho,
      () => cong.khiMo(() {
        c.chay();
        AppLifecycleListener(onResume: c.chay);
      }),
    ),
  );
}

/// Một lượt chạy + hẹn thử lại. Tách khỏi [batDauDinhDanh] để test được.
final class ChayDinhDanh {
  new(this._dv, {this._hen = Timer.new, this._duocChay = _luon});

  static bool _luon() => true;

  final DichVuDinhDanh _dv;

  /// false -> bỏ lượt (đã rút đồng ý), kể cả lượt thử lại đã hẹn.
  final bool Function() _duocChay;
  final Timer Function(Duration, void Function()) _hen;
  Timer? _cho;
  int _lan = 0;

  /// Số lần thử lại đã hẹn liên tiếp (test).
  int get lanThuLai => _lan;

  void chay() => unawaited(_chay());

  Future<void> _chay() async {
    _cho?.cancel();
    _cho = null;
    if (!_duocChay()) {
      _lan = 0;
      return;
    }
    final kq = await _dv.damBaoPhien();
    switch (kq) {
      case Ok():
        _lan = 0;
        // Mức tin cậy kẹt `unverified` khi Play Integrity lỗi lúc đăng ký ->
        // xác minh lại theo lịch (lỗi ở lượt này không ảnh hưởng phiên).
        unawaited(_dv.xacMinhLaiNeuCan());
      case Err(:final failure):
        final cho = LichThuLai.cho(_lan, failure.code);
        if (cho == null) {
          _lan = 0;
          return;
        }
        _lan++;
        _cho = _hen(cho, chay);
    }
  }
}
