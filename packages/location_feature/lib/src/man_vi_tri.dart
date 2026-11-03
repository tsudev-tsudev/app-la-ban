import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:location_feature/src/domain/doc_vi_tri.dart';
import 'package:location_feature/src/domain/thien_van.dart';
import 'package:location_feature/src/domain/thuoc_thuy.dart';
import 'package:location_feature/src/domain/toa_do.dart';
import 'package:location_feature/src/domain/tu_truong.dart';
import 'package:location_feature/src/hien_thi.dart';
import 'package:location_feature/src/the_vi_tri.dart';
import 'package:location_feature/src/vi_tri_provider.dart';
import 'package:sensors/sensors.dart';

/// Màn vị trí & thông số: toạ độ 4 định dạng, địa giới, độ cao GPS / khí
/// áp, di chuyển, từ trường so WMM, thước thuỷ, mặt trời / mặt trăng. Mỗi mục
/// tự nghe đúng nguồn của nó - mục cảm biến dựng lại theo cảm biến, mục
/// thiên văn chỉ mỗi phút.
class ManViTri extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.locTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(LbSpacing.md),
          children: const [
            _GiuaHep(child: _MucToaDo()),
            _GiuaHep(child: _MucDoCao()),
            _GiuaHep(child: _MucTuTruong()),
            _GiuaHep(child: _MucThuocThuy()),
            _GiuaHep(child: _MucThienVan(matTrang: false)),
            _GiuaHep(child: _MucThienVan(matTrang: true)),
          ],
        ),
      ),
    );
  }
}

class _GiuaHep extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: child,
    ),
  );
}

class _Muc extends StatelessWidget {
  const new({required this.tieuDe, required this.icon, required this.con});

  final String tieuDe;
  final LbIconData icon;
  final List<Widget> con;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: LbSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(LbSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                LbIcon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: LbSpacing.xs),
                Expanded(
                  child: Text(tieuDe, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: LbSpacing.xs),
            ...con,
          ],
        ),
      ),
    );
  }
}

/// Một dòng nhãn - giá trị; hẹp thì giá trị xuống dòng dưới nhãn.
class _Dong extends StatelessWidget {
  const new({required this.nhan, required this.giaTri, this.sau});

  final String nhan;
  final String giaTri;
  final Widget? sau;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gt = Text(
      giaTri,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LbSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: LbSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  nhan,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                gt,
              ],
            ),
          ),
          ?sau,
        ],
      ),
    );
  }
}

class _GhiChu extends StatelessWidget {
  const new(this.chu, {this.canhBao = false});

  final String chu;
  final bool canhBao;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: LbSpacing.xs),
      child: Text(
        chu,
        style: theme.textTheme.bodySmall?.copyWith(
          color: canhBao ? theme.colorScheme.error : null,
        ),
      ),
    );
  }
}

DocViTri? _doc(WidgetRef ref) => ref.watch(docViTriProvider).value;

class _MucToaDo extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = _doc(ref);
    final quyen = ref.watch(quyenViTriProvider).value;
    if (d == null) {
      return _Muc(
        tieuDe: l10n.locSectionCoords,
        icon: LbIcons.ghimGps,
        // Thẻ gọn lo cả lời mời bật quyền lẫn trạng thái chờ.
        con: const [TheViTriNoiDung()],
      );
    }
    final dg = ref.watch(diaGioiProvider);
    final tiengViet = Localizations.localeOf(context).languageCode == 'vi';
    return _Muc(
      tieuDe: l10n.locSectionCoords,
      icon: LbIcons.ghimGps,
      con: [
        for (final dd in DinhDangToaDo.values)
          if (dinhDangToaDo(dd, d.viDo, d.kinhDo) case final s?)
            _Dong(
              nhan: tenDinhDang(l10n, dd),
              giaTri: s,
              sau: TextButton(
                onPressed: () => chepToaDo(context, s),
                child: Text(l10n.locCopy),
              ),
            ),
        _Dong(
          nhan: l10n.locHorizontalAccuracy,
          giaTri: [
            if (d.doChinhXacNgang case final a?) l10n.locAccuracy(a.round()),
            tenNguon(l10n, d.nguon),
            if (quyen == QuyenViTri.xapXi) l10n.locApproximate,
          ].join(' · '),
        ),
        const Divider(height: LbSpacing.lg),
        Text(
          l10n.locSectionPlace,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        _GhiChu(
          dg == null
              ? l10n.locOutsideVn
              : [
                  dg.tenXa(tiengViet: tiengViet),
                  dg.tenTinh(tiengViet: tiengViet),
                ].nonNulls.join(', '),
        ),
        _GhiChu(l10n.locOsmCredit),
        const Divider(height: LbSpacing.lg),
        Text(
          l10n.locSectionMotion,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        _Dong(
          nhan: l10n.locSpeed,
          giaTri: d.tocDo == null
              ? l10n.locNotAvailable
              : l10n.locKmh(double.parse((d.tocDo! * 3.6).toStringAsFixed(1))),
        ),
        _Dong(
          nhan: l10n.locCourse,
          giaTri: d.huongDi == null || (d.tocDo ?? 0) < 0.5
              ? l10n.locNotAvailable
              : l10n.locDegrees(d.huongDi!.round() % 360),
        ),
      ],
    );
  }
}

/// Nội dung thẻ gọn (không viền) để nhúng khi chưa có vị trí.
class TheViTriNoiDung extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const TheViTri(coVien: false);
}

class _MucDoCao extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = _doc(ref);
    final geoid = ref.watch(taiNguyenViTriProvider).value?.geoid;
    final apSuat = ref.watch(huongProvider.select((h) => h.value?.apSuat));
    final bo = ref.read(boHieuChinhKhiApProvider);
    final cao = d == null ? null : doCaoMucBien(d, geoid);
    if (d != null) bo.nap(apSuat, cao, d.doChinhXacDung);
    return _Muc(
      tieuDe: l10n.locSectionAltitude,
      icon: LbIcons.matLaBan3d,
      con: [
        _Dong(
          nhan: l10n.locAltGps,
          giaTri: cao == null
              ? l10n.locNotAvailable
              : d!.doChinhXacDung == null
              ? l10n.locMeters(cao.round())
              : l10n.locMetersPm(cao.round(), d.doChinhXacDung!.round()),
        ),
        if (apSuat != null) ...[
          _Dong(
            nhan: l10n.locAltBaro,
            giaTri: l10n.locMeters(bo.doCao(apSuat).round()),
          ),
          _Dong(
            nhan: l10n.locPressure,
            giaTri: l10n.locHpa(double.parse(apSuat.toStringAsFixed(1))),
          ),
          _GhiChu(
            bo.daHieuChinh ? l10n.locBaroCalibrated : l10n.locBaroStandard,
          ),
        ],
      ],
    );
  }
}

class _MucTuTruong extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_MucTuTruong> createState() => _MucTuTruongState();
}

class _MucTuTruongState extends ConsumerState<_MucTuTruong> {
  /// Cảnh báo có trễ hai ngưỡng + giữ tối thiểu: nam châm dao động quanh
  /// ngưỡng không làm cảnh báo bật / tắt liên tục (A9c).
  var _tre = const TreCanhBao();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mau = ref.watch(
      huongProvider.select(
        (h) => h.value == null ? null : (h.value!.cuongDoTu, h.value!.tNs),
      ),
    );
    final mh = ref.watch(tuTruongProvider);
    final ut = mau?.$1;
    if (ut == null || !ut.isFinite) return const SizedBox.shrink();
    final dg = danhGiaTuTruong(ut, moHinhNt: mh?.f);
    _tre = _tre.capNhat(
      vuotNguongBat: dg.batThuong,
      duoiNguongTat: dg.yen,
      luc: DateTime.fromMicrosecondsSinceEpoch(mau!.$2 ~/ 1000),
    );
    double mot(double v) => double.parse(v.toStringAsFixed(1));
    return _Muc(
      tieuDe: l10n.locSectionField,
      icon: LbIcons.khien,
      con: [
        _Dong(nhan: l10n.locFieldMeasured, giaTri: l10n.locMicroTesla(mot(ut))),
        if (dg.moHinh case final m?)
          _Dong(
            nhan: l10n.locFieldModel,
            giaTri: [
              l10n.locMicroTesla(mot(m)),
              if (dg.lechPhanTram case final p?)
                l10n.locFieldDeviation(p.round()),
            ].join(' · '),
          ),
        LbOCoDinh(
          chiSo: _tre.dangBat ? 1 : 0,
          phuongAn: [
            _GhiChu(l10n.a9FieldNormal),
            _GhiChu(l10n.locFieldAbnormal, canhBao: true),
          ],
        ),
      ],
    );
  }
}

class _MucThuocThuy extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_MucThuocThuy> createState() => _MucThuocThuyState();
}

class _MucThuocThuyState extends ConsumerState<_MucThuocThuy> {
  var _canBang = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final goc = ref.watch(
      huongProvider.select(
        (h) => h.value == null ? null : (h.value!.doc, h.value!.lan),
      ),
    );
    if (goc == null) return const SizedBox.shrink();
    final t = tinhThuocThuy(goc.$1, goc.$2, canBangTruoc: _canBang);
    _canBang = t.canBang;
    final theme = Theme.of(context);
    final mauOk = LbThemeExt.of(context).colors.successStrong;
    return _Muc(
      tieuDe: l10n.locSectionLevel,
      icon: LbIcons.thuocThuy,
      con: [
        Center(
          child: Semantics(
            label: t.canBang
                ? l10n.locLevelOk
                : l10n.locLevelTilt(double.parse(t.nghieng.toStringAsFixed(1))),
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: 160,
              child: CustomPaint(
                painter: _VeThuoc(
                  x: t.x,
                  y: t.y,
                  vien: theme.colorScheme.outline,
                  bot: t.canBang ? mauOk : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: LbSpacing.xs),
        Text(
          t.canBang
              ? l10n.locLevelOk
              : l10n.locLevelTilt(double.parse(t.nghieng.toStringAsFixed(1))),
          textAlign: TextAlign.center,
          style: LbType.telemetry.copyWith(
            color: t.canBang ? mauOk : theme.colorScheme.onSurface,
          ),
        ),
        if (t.nghieng > 45) _GhiChu(l10n.locLevelHint),
      ],
    );
  }
}

class _VeThuoc extends CustomPainter {
  const new({
    required this.x,
    required this.y,
    required this.vien,
    required this.bot,
  });

  final double x;
  final double y;
  final Color vien;
  final Color bot;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    final butVien = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = vien;
    canvas
      ..drawCircle(c, r, butVien)
      ..drawCircle(c, r * 0.18, butVien)
      ..drawLine(c - Offset(r, 0), c + Offset(r, 0), butVien..strokeWidth = 1)
      ..drawLine(c - Offset(0, r), c + Offset(0, r), butVien);
    final rb = r * 0.15;
    final tam = c + Offset(x, y) * (r - rb);
    canvas.drawCircle(tam, rb, Paint()..color = bot.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_VeThuoc old) =>
      old.x != x || old.y != y || old.vien != vien || old.bot != bot;
}

class _MucThienVan extends ConsumerWidget {
  const new({required this.matTrang});

  final bool matTrang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final vt = ref.watch(viTriProvider);
    final bayGio = ref.watch(phutProvider).value;
    final tieuDe = matTrang ? l10n.locSectionMoon : l10n.locSectionSun;
    final icon = matTrang ? LbIcons.laBanHoaGio : LbIcons.bacThuc;
    if (vt == null || bayGio == null) {
      return _Muc(
        tieuDe: tieuDe,
        icon: icon,
        con: [_GhiChu(l10n.locNeedLocationSky)],
      );
    }
    final lech = ref.read(lechMuiGioProvider)(bayGio);
    final tu = nuaDemHomNay(bayGio, lech);
    final sk = matTrang
        ? suKienMatTrang(tu, vt.viDo, vt.kinhDo)
        : suKienMatTroi(tu, vt.viDo, vt.kinhDo);
    final p = matTrang
        ? viTriMatTrang(bayGio, vt.viDo, vt.kinhDo)
        : viTriMatTroi(bayGio, vt.viDo, vt.kinhDo);
    String gio(DateTime? t) => t == null ? '-' : gioPhut(context, ref, t);
    final pha = matTrang ? phaMatTrang(bayGio) : null;
    return _Muc(
      tieuDe: tieuDe,
      icon: icon,
      con: [
        if (sk.moc == null && sk.lan == null)
          _GhiChu(sk.luonTren ? l10n.locAlwaysUp : l10n.locAlwaysDown)
        else ...[
          _Dong(nhan: l10n.locRise, giaTri: gio(sk.moc)),
          _Dong(nhan: l10n.locSet, giaTri: gio(sk.lan)),
        ],
        _Dong(
          nhan: matTrang ? l10n.locTransit : l10n.locNoon,
          giaTri: gio(sk.dinh),
        ),
        _Dong(
          nhan: l10n.locNow,
          giaTri: l10n.locSkyPosition(
            p.phuongVi.round() % 360,
            (p.doCao + khucXa(p.doCao)).round(),
          ),
        ),
        if (pha != null)
          _Dong(
            nhan: tenPhaTrang(l10n, tenPha(pha)),
            giaTri: l10n.locMoonIllumination(
              math.min(100, (pha.sang * 100).round()),
            ),
          ),
      ],
    );
  }
}
