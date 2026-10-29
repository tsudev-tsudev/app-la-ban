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

DichVuDinhDanh taoDichVuDinhDanh(Flavor flavor, KhoLuuTru kho) {
  final pb = tachPhienBan(phienBanApp);
  return DichVuDinhDanh(
    api: ApiClientIo(flavor.apiGoc),
    nenTang: const NenTangThietBiKenh(),
    tep: TepJson.mo('${kho.thuMuc}/dinh_danh.json'),
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
