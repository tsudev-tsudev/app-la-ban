import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/phien_ban.dart';
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

DichVuDinhDanh taoDichVuDinhDanh(Flavor flavor, KhoLuuTru kho) {
  final pb = tachPhienBan(phienBanApp);
  return DichVuDinhDanh(
    api: ApiDinhDanhIo(ApiClientIo(flavor.apiGoc)),
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
/// đầu, lỗi (offline, Google lỗi) bỏ qua: la bàn chạy đủ khi không có mạng.
void batDauDinhDanh(
  DichVuDinhDanh dv, {
  Duration cho = const Duration(seconds: 3),
}) {
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => Timer(cho, () => unawaited(dv.damBaoPhien())),
  );
}
