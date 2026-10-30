import 'dart:math';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:sensors/sensors.dart';
import 'package:waypoint_feature/src/domain/dan_duong.dart';
import 'package:waypoint_feature/src/hien_thi.dart';
import 'package:waypoint_feature/src/icon_diem.dart';
import 'package:waypoint_feature/src/providers.dart';
import 'package:waypoint_feature/src/the_vi_tri_diem.dart';

/// Góc quay coi như "đi thẳng" (độ).
const _thang = 10.0;

/// Dẫn đường tới một điểm: mũi tên theo la bàn (bắc thực, Vincenty trên
/// WGS84), khoảng cách, sai số GPS.
class ManDanDuong extends ConsumerWidget {
  const new({
    required this.ten,
    required this.viDo,
    required this.kinhDo,
    super.key,
  });

  final String ten;
  final double viDo;
  final double kinhDo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final chu = Theme.of(context).textTheme;
    final mau = Theme.of(context).colorScheme;
    final v = ref.watch(viTriDiemProvider);
    final huong = ref.watch(huongProvider);
    final coLaBan = !huong.hasError;
    Widget than;
    if (v is! ViTriCo) {
      than = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (v is ViTriDangCho) Text(l.wpWaitingGps, style: chu.titleMedium),
          const SizedBox(height: LbSpacing.md),
          TheViTriDiem(onDung: (_) {}, dangCho: true),
        ],
      );
    } else {
      final vt = v.viTri;
      final tu = ref.watch(tuTruongProvider.select((t) => t?.doLech));
      final doLech =
          tu ??
          tinhTuTruong(
            ref.watch(heSoWmmProvider),
            viDo: vt.viDo,
            kinhDo: vt.kinhDo,
            doCaoKm: (vt.caoDo ?? 0) / 1000,
            nam: namThapPhan(ref.watch(dongHoProvider)()),
          ).doLech;
      final dd = tinhDanDuong(
        viDo: vt.viDo,
        kinhDo: vt.kinhDo,
        dichViDo: viDo,
        dichKinhDo: kinhDo,
        saiSoM: vt.saiSoM,
        huongTu: huong.value?.phuongVi,
        doLech: doLech.isFinite ? doLech : 0,
      );
      final kc = khoangCach(l, dd.khoangCachM);
      final goc = dd.gocQuay;
      final String? chiDan;
      if (dd.daToi) {
        chiDan = l.wpArrived;
      } else if (goc != null) {
        chiDan = goc.abs() <= _thang
            ? l.wpAhead
            : l.wpTurn(goc.abs().round(), goc > 0 ? l.wpRight : l.wpLeft);
      } else {
        // Chưa có hướng: đang khởi động cảm biến, hoặc máy không có la bàn.
        chiDan = coLaBan ? null : l.wpNoCompass;
      }
      than = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l.wpArrowSemantics(ten, kc),
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: 180,
                child: dd.daToi
                    ? LbIcon(LbIcons.diemMoc, size: 160, color: mau.primary)
                    : Transform.rotate(
                        // Không la bàn: mũi tên chỉ theo phương vị so với
                        // bắc (đầu màn hình = bắc).
                        angle: (goc ?? dd.phuongVi) * pi / 180,
                        child: LbIcon(
                          IconDiem.muiTen,
                          size: 160,
                          color: mau.primary,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: LbSpacing.md),
          Text(kc, style: chu.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: LbSpacing.xs),
          if (chiDan != null)
            Text(chiDan, style: chu.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: LbSpacing.xs),
          Text(
            l.wpBearing(dd.phuongVi.round() % 360),
            style: chu.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (vt.saiSoM != null)
            Text(
              l.wpAccuracy(vt.saiSoM!.round()),
              style: chu.bodyMedium?.copyWith(color: mau.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(ten, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, rang) => SingleChildScrollView(
            padding: const EdgeInsets.all(LbSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: max(0, rang.maxHeight - 2 * LbSpacing.lg),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: than,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
