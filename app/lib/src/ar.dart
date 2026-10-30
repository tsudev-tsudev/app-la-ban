import 'package:ar_feature/ar_feature.dart';
import 'package:compass_feature/compass_feature.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:i18n/i18n.dart';
import 'package:la_ban/src/diem.dart';
import 'package:la_ban/src/luu_tru.dart';
import 'package:storage/storage.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// Nối Camera AR (A7c) với phần còn lại của app (tính năng không gọi nhau):
/// hướng bắc thực của compass_feature, điểm của waypoint_feature, vị trí của
/// location_feature (qua [viTriChoDiem]).
List<Override> noiAr() => [
  docArProvider.overrideWith((ref) {
    final h = ref.watch(huongProvider).value;
    if (h == null) return null;
    final pv = tinhHuongHienThi(
      h.phuongVi,
      muonBacThuc: true,
      tuTruong: ref.watch(tuTruongProvider),
    ).phuongVi;
    return (
      camera: (phuongVi: pv, ngoc: h.ngocCamera, lan: h.lan),
      dungDung: h.theoCamera,
      canHieuChuan: h.canHieuChuan || h.nhieuTu,
    );
  }),
  coViTriArProvider.overrideWith((ref) => viTriChoDiem(ref) is ViTriCo),
  diemArProvider.overrideWith((ref) {
    if (viTriChoDiem(ref) case ViTriCo(:final viTri)) {
      final ds = <DiemAr>[];
      for (final d in ref.watch(dsDiemProvider).value ?? const <DiemMoc>[]) {
        final t = tracDia(viTri.viDo, viTri.kinhDo, d.viDo, d.kinhDo);
        final (a, b) = (viTri.caoDo, d.caoDo);
        ds.add((
          id: d.id,
          ten: d.ten,
          phuongVi: t.phuongViDau,
          khoangCachM: t.khoangCachM,
          ngoc: a != null && b != null ? gocNgocToi(t.khoangCachM, b - a) : 0,
        ));
      }
      return ds..sort((a, b) => a.khoangCachM.compareTo(b.khoangCachM));
    }
    return const [];
  }),
];

/// Nút mở Camera AR trên thanh tiêu đề màn La bàn; ẩn khi cờ `ar` tắt.
class NutAr extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(coTinhNangProvider)[CoTinhNang.ar]!) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: context.l10n.arOpen,
      icon: const LbIcon(LbIcons.cameraAr),
      onPressed: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const ManAr(),
        ),
      ),
    );
  }
}
