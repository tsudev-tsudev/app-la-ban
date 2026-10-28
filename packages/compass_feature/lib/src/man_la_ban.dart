import 'dart:math' as math;

import 'package:compass_feature/src/bac_thuc_provider.dart';
import 'package:compass_feature/src/domain/huong_hien_thi.dart';
import 'package:compass_feature/src/domain/moc_rung.dart';
import 'package:compass_feature/src/man_hieu_chuan.dart';
import 'package:compass_feature/src/mat_la_ban.dart';
import 'package:compass_feature/src/tuy_chon_provider.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:sensors/sensors.dart';

/// Tab La bàn: mặt la bàn CustomPainter, số độ 0,1°, 8 hướng, bắc thực /
/// bắc từ (WMM2025 ngoại tuyến), độ tin cậy, cảnh báo nhiễu từ, hiệu chuẩn.
class ManLaBan extends ConsumerStatefulWidget {
  const new({this.theDuoi, super.key});

  /// Thẻ app gắn dưới phần thông tin (thẻ vị trí của location_feature - tính
  /// năng không gọi nhau, app nối). Chỉ dựng khi tab đang thấy.
  final Widget? theDuoi;

  @override
  ConsumerState<ManLaBan> createState() => _ManLaBanState();
}

class _ManLaBanState extends ConsumerState<ManLaBan> {
  late final AppLifecycleListener _vongDoi;
  var _truocMat = true;
  final _rungMoc = BoRungMoc();

  @override
  void initState() {
    super.initState();
    _vongDoi = AppLifecycleListener(
      onStateChange: (s) {
        final moi = s == AppLifecycleState.resumed;
        if (moi != _truocMat) setState(() => _truocMat = moi);
      },
    );
  }

  @override
  void dispose() {
    _vongDoi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Tab ẩn trong StatefulShellRoute có TickerMode tắt. Chỉ nghe cảm biến khi
    // màn đang thấy và app ở tiền cảnh - thôi nghe = tắt cảm biến (Spec §4.1).
    final dangThay = _truocMat && TickerMode.valuesOf(context).enabled;
    final Widget than;
    if (!dangThay) {
      _rungMoc.datLai();
      than = const SizedBox.shrink();
    } else {
      final tuyChon = ref.watch(tuyChonLaBanProvider);
      final tuTruong = ref.watch(tuTruongProvider);
      HuongHienThi doi(HuongDoc h) => tinhHuongHienThi(
        h.phuongVi,
        muonBacThuc: tuyChon.bacThuc,
        tuTruong: tuTruong,
      );
      ref.listen(huongProvider, (_, moi) {
        if (moi case AsyncData(:final value)) {
          final moc = _rungMoc.nap(doi(value).phuongVi);
          if (moc != null && ref.read(tuyChonLaBanProvider).rung) {
            ref.read(rungProvider)();
          }
        }
      });
      than = switch (ref.watch(huongProvider)) {
        AsyncData(:final value) => _DocHuong(
          h: value,
          hh: doi(value),
          theDuoi: widget.theDuoi,
        ),
        AsyncError(:final error) => LbTrangTrong(
          hinh: const LbIcon(LbIcons.laBanHoaGio, size: 96),
          moTa: error is NgoaiLeCamBien && error.loi == LoiCamBien.khongCoLaBan
              ? l10n.compassNoSensor
              : l10n.compassError,
        ),
        _ => LbTrangTrong(
          hinh: const SizedBox.square(
            dimension: 48,
            child: CircularProgressIndicator(),
          ),
          moTa: l10n.compassStarting,
        ),
      };
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabCompass),
        actions: [
          IconButton(
            tooltip: l10n.compassCalibrateAction,
            icon: const LbIcon(LbIcons.hieuChuanSo8),
            onPressed: () => moHieuChuan(context),
          ),
          IconButton(
            tooltip: l10n.compassOptions,
            icon: const LbIcon(LbIcons.bacThuc),
            onPressed: () => moTuyChon(context),
          ),
        ],
      ),
      body: than,
    );
  }
}

/// Mở màn hiệu chuẩn hình số 8 (toàn màn, che thanh tab).
Future<void> moHieuChuan(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const ManHieuChuan(),
      ),
    );

/// Bảng tuỳ chọn: bắc thực / bắc từ, rung.
Future<void> moTuyChon(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const BangTuyChon(),
);

class BangTuyChon extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = ref.watch(tuyChonLaBanProvider);
    final n = ref.read(tuyChonLaBanProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: LbSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LbSpacing.md),
              child: Text(
                l10n.compassOptions,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SwitchListTile(
              value: t.bacThuc,
              onChanged: (v) => n.datBacThuc(bat: v),
              title: Text(l10n.compassOptionTrueNorth),
              subtitle: Text(l10n.compassOptionTrueNorthHint),
            ),
            SwitchListTile(
              value: t.rung,
              onChanged: (v) => n.datRung(bat: v),
              title: Text(l10n.compassOptionHaptic),
              subtitle: Text(l10n.compassOptionHapticHint),
            ),
          ],
        ),
      ),
    );
  }
}

String tenNgan(LbL10n l, HuongChinh h) => switch (h) {
  HuongChinh.bac => l.dirShortN,
  HuongChinh.dongBac => l.dirShortNE,
  HuongChinh.dong => l.dirShortE,
  HuongChinh.dongNam => l.dirShortSE,
  HuongChinh.nam => l.dirShortS,
  HuongChinh.tayNam => l.dirShortSW,
  HuongChinh.tay => l.dirShortW,
  HuongChinh.tayBac => l.dirShortNW,
};

String tenDai(LbL10n l, HuongChinh h) => switch (h) {
  HuongChinh.bac => l.dirLongN,
  HuongChinh.dongBac => l.dirLongNE,
  HuongChinh.dong => l.dirLongE,
  HuongChinh.dongNam => l.dirLongSE,
  HuongChinh.nam => l.dirLongS,
  HuongChinh.tayNam => l.dirLongSW,
  HuongChinh.tay => l.dirLongW,
  HuongChinh.tayBac => l.dirLongNW,
};

String tenMuc(LbL10n l, MucTinCay m) => switch (m) {
  MucTinCay.cao => l.accuracyHigh,
  MucTinCay.trungBinh => l.accuracyMedium,
  MucTinCay.thap => l.accuracyLow,
};

class _DocHuong extends StatelessWidget {
  const new({required this.h, required this.hh, this.theDuoi});

  final HuongDoc h;
  final HuongHienThi hh;
  final Widget? theDuoi;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, rang) {
        // Màn ngang đủ rộng: mặt la bàn bên trái, thông tin bên phải.
        final ngang =
            rang.maxWidth >= 600 && rang.maxWidth > rang.maxHeight * 1.2;
        final canh = ngang
            ? math.min(rang.maxHeight - 2 * LbSpacing.lg, rang.maxWidth * 0.45)
            : math.min(rang.maxWidth - 2 * LbSpacing.lg, rang.maxHeight * 0.55);
        final mat = Semantics(
          label: l10n.compassHeadingSemantics(
            hh.soDo01.round() % 360,
            tenDai(l10n, huongChinh(hh.phuongVi)),
          ),
          excludeSemantics: true,
          child: MatLaBan(
            phuongVi: hh.phuongVi,
            canh: math.max(120, math.min(380, canh)),
            nhan8: [for (final c in HuongChinh.values) tenNgan(l10n, c)],
            mau: MauMatLaBan.tuTheme(context),
          ),
        );
        final thongTin = theDuoi == null
            ? _ThongTin(h: h, hh: hh)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThongTin(h: h, hh: hh),
                  theDuoi!,
                ],
              );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(LbSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, rang.maxHeight - 2 * LbSpacing.lg),
            ),
            child: Center(
              child: ngang
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        mat,
                        const SizedBox(width: LbSpacing.xl),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: thongTin,
                          ),
                        ),
                      ],
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          mat,
                          const SizedBox(height: LbSpacing.md),
                          thongTin,
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ThongTin extends StatelessWidget {
  const new({required this.h, required this.hh});

  final HuongDoc h;
  final HuongHienThi hh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final mau = theme.colorScheme;
    final tk = LbThemeExt.of(context).colors;
    final huong = huongChinh(hh.phuongVi);
    final mauMuc = switch (h.muc) {
      MucTinCay.cao => tk.successStrong,
      MucTinCay.trungBinh => tk.warningStrong,
      MucTinCay.thap => tk.dangerStrong,
    };
    final doLech = hh.doLech;
    final dongThamChieu = [
      if (hh.bacThuc) l10n.compassTrueNorth else l10n.compassMagneticNorth,
      if (doLech != null)
        l10n.compassDeclination(
          double.parse(doLech.abs().toStringAsFixed(1)),
          doLech < 0 ? l10n.dirLongW : l10n.dirLongE,
        ),
    ].join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Số độ luôn một dòng: chữ hệ thống rất lớn thì thu nhỏ vừa bề
        // ngang thay vì vỡ dòng.
        ExcludeSemantics(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l10n.compassHeadingPrecise(hh.soDo01)),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: tenNgan(l10n, huong),
                    style: TextStyle(color: tk.primaryDeep),
                  ),
                ],
              ),
              maxLines: 1,
              style: LbType.telemetryLarge.copyWith(color: mau.onSurface),
            ),
          ),
        ),
        Text(
          dongThamChieu,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LbSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: LbSpacing.xs,
          runSpacing: LbSpacing.xs,
          children: [
            _Nhan(cham: mauMuc, chu: l10n.compassAccuracy(tenMuc(l10n, h.muc))),
            if (h.cuongDoTu.isFinite)
              _Nhan(chu: l10n.compassFieldStrength(h.cuongDoTu.round())),
            _Nhan(chu: l10n.compassTilt(h.doc.round(), h.lan.round())),
            if (h.theoCamera) _Nhan(chu: l10n.compassCameraMode),
          ],
        ),
        if (h.nhieuTu)
          _CanhBao(
            icon: LbIcons.khien,
            noiDung: l10n.compassInterference,
            hanhDong: l10n.compassCalibrateAction,
          )
        else if (h.canHieuChuan)
          _CanhBao(
            icon: LbIcons.hieuChuanSo8,
            noiDung: l10n.compassCalibrate,
            hanhDong: l10n.compassCalibrateAction,
          ),
        if (hh.thieuViTri)
          _GhiChu(icon: LbIcons.ghimGps, noiDung: l10n.compassNeedLocation)
        else if (hh.moHinhCu)
          _GhiChu(icon: LbIcons.bacThuc, noiDung: l10n.compassModelExpired),
      ],
    );
  }
}

/// Nhãn viền bo tròn, chữ dài thì xuống dòng (Chip cắt chữ khi phóng to).
class _Nhan extends StatelessWidget {
  const new({required this.chu, this.cham});

  final String chu;
  final Color? cham;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(LbRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LbSpacing.sm,
          vertical: LbSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cham case final c?) ...[
              DecoratedBox(
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 10),
              ),
              const SizedBox(width: LbSpacing.xs),
            ],
            Flexible(child: Text(chu, style: theme.textTheme.labelLarge)),
          ],
        ),
      ),
    );
  }
}

class _CanhBao extends StatelessWidget {
  const new({
    required this.icon,
    required this.noiDung,
    required this.hanhDong,
  });

  final LbIconData icon;
  final String noiDung;
  final String hanhDong;

  @override
  Widget build(BuildContext context) {
    final mau = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: LbSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: mau.errorContainer,
            borderRadius: BorderRadius.circular(LbRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(LbSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    LbIcon(icon, color: mau.onErrorContainer),
                    const SizedBox(width: LbSpacing.sm),
                    Expanded(
                      child: Text(
                        noiDung,
                        style: TextStyle(color: mau.onErrorContainer),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: mau.onErrorContainer,
                  ),
                  onPressed: () => moHieuChuan(context),
                  child: Text(hanhDong),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GhiChu extends StatelessWidget {
  const new({required this.icon, required this.noiDung});

  final LbIconData icon;
  final String noiDung;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: LbSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LbIcon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: LbSpacing.xs),
          Expanded(child: Text(noiDung, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
