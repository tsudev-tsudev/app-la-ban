import 'package:app_shell/src/diem.dart';
import 'package:app_shell/src/flavor.dart';
import 'package:compass_feature/compass_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:location_feature/location_feature.dart';
import 'package:map_feature/map_feature.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// Nối tab Bản đồ (A7b) với phần còn lại của app (tính năng không gọi nhau):
/// gốc Worker theo flavor, điểm của waypoint_feature, vị trí + quyền của
/// location_feature, hướng bắc thực của compass_feature.
List<Override> noiBanDo(Flavor flavor) => [
  // dev: `wrangler dev` không có tile R2 -> dùng /ban-do của staging (công khai).
  gocBanDoProvider.overrideWithValue(
    (flavor == Flavor.dev ? Flavor.staging : flavor).apiGoc.toString(),
  ),
  diemBanDoProvider.overrideWith(
    (ref) => [
      for (final d in ref.watch(dsDiemProvider).value ?? const <DiemMoc>[])
        (id: d.id, ten: d.ten, viDo: d.viDo, kinhDo: d.kinhDo),
    ],
  ),
  viTriBanDoProvider.overrideWith((ref) {
    final t = viTriChoDiem(ref);
    return t is ViTriCo
        ? (viDo: t.viTri.viDo, kinhDo: t.viTri.kinhDo, saiSoM: t.viTri.saiSoM)
        : null;
  }),
  coQuyenViTriBanDoProvider.overrideWith(
    (ref) => ref.watch(quyenViTriProvider).value?.duocPhep ?? false,
  ),
  xinQuyenViTriBanDoProvider.overrideWith(
    (ref) =>
        () => ref.read(quyenViTriProvider.notifier).xin(),
  ),
  huongBanDoProvider.overrideWith((ref) {
    final h = ref.watch(huongProvider).value;
    if (h == null) return null;
    return tinhHuongHienThi(
      h.phuongVi,
      muonBacThuc: true,
      tuTruong: ref.watch(tuTruongProvider),
    ).phuongVi;
  }),
  moDiemBanDoProvider.overrideWithValue(
    (context, id) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => ManChiTietDiem(id: id))),
  ),
];
