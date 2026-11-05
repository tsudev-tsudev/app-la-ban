import 'dart:convert';

import 'package:app_shell/src/dinh_danh.dart';
import 'package:app_shell/src/phien_ban.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:location_feature/location_feature.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:storage/storage.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// Một điểm mốc trong tệp xuất: thời điểm dạng ISO 8601 (đọc được ngoài app).
@visibleForTesting
Map<String, Object?> diemXuat(DiemTho d) => {
  'id': d.id,
  'ten': d.ten,
  'viDo': d.viDo,
  'kinhDo': d.kinhDo,
  'caoDo': d.caoDo,
  'ghiChu': d.ghiChu,
  'taoLuc': _iso(d.taoLuc),
  'suaLuc': _iso(d.suaLuc),
};

String _iso(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

/// Nối màn Quyền riêng tư (settings_feature) với kho lưu trữ, định danh
/// thiết bị, kênh nền tảng của tab Điểm (lưu tệp) và location_feature (mở cài
/// đặt app). Điểm đọc thô qua `docDiemAnToan` - chạy cả ở chế độ an toàn.
List<Override> noiRiengTu(
  KhoLuuTru? kho, {
  NenTangDiem nenTang = const NenTangDiemKenh(),
  Future<void> Function() xoaToanBo = xoaToanBoDuLieuApp,
  Future<bool> Function(Uri) moLienKet = moTrangLaBan,
}) => [
  hanhDongRiengTuProvider.overrideWith((ref) {
    final dv = ref.watch(dichVuDinhDanhProvider);
    return HanhDongRiengTu(
      demDiem: kho == null
          ? null
          : () async => (await kho.docDiemAnToan()).length,
      xuatDuLieu: kho == null
          ? null
          : () async {
              final luc = DateTime.now();
              final goi = goiDuLieuXuat(
                phienBanApp: phienBanApp,
                luc: luc,
                caiDat: kho.caiDat.duLieu,
                tuyChonLaBan: kho.laBan.duLieu,
                viTri: kho.viTri.duLieu,
                diem: [for (final d in await kho.docDiemAnToan()) diemXuat(d)],
                maThietBi: dv?.phien?.thietBiId,
              );
              final byte = utf8.encode(
                const JsonEncoder.withIndent('  ').convert(goi),
              );
              return await nenTang.luuTep(
                tenTepXuat(luc),
                'application/json',
                byte,
              );
            },
      xoaToanBo: kho == null ? null : xoaToanBo,
      maThietBi: dv == null ? null : () => dv.phien?.thietBiId,
      moLienKet: moLienKet,
      moCaiDatHeThong: () => ref.read(nguonViTriProvider).moCaiDatApp(),
    );
  }),
];
