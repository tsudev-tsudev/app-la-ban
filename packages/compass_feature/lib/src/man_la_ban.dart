import 'dart:math' as math;

import 'package:compass_feature/src/huong_provider.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:sensors/sensors.dart';

/// Tab La bàn - bản đọc hướng của A2 (hoa gió xoay theo bắc từ, số độ, độ tin
/// cậy, cảnh báo nhiễu / hiệu chuẩn). Mặt la bàn CustomPainter + bắc thực ở A3.
class ManLaBan extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ManLaBan> createState() => _ManLaBanState();
}

class _ManLaBanState extends ConsumerState<ManLaBan> {
  late final AppLifecycleListener _vongDoi;
  var _truocMat = true;

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
      than = const SizedBox.shrink();
    } else {
      than = switch (ref.watch(huongProvider)) {
        AsyncData(:final value) => _DocHuong(h: value),
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
      appBar: AppBar(title: Text(l10n.tabCompass)),
      body: than,
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
  const new({required this.h});

  final HuongDoc h;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final mau = theme.colorScheme;
    final tk = LbThemeExt.of(context).colors;
    final so = h.phuongVi.round() % 360;
    final huong = huongChinh(h.phuongVi);
    final mauMuc = switch (h.muc) {
      MucTinCay.cao => tk.successStrong,
      MucTinCay.trungBinh => tk.warningStrong,
      MucTinCay.thap => tk.dangerStrong,
    };
    return LayoutBuilder(
      builder: (context, rang) {
        final canh = math.min(240, rang.biggest.shortestSide * 0.5).toDouble();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(LbSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, rang.maxHeight - 2 * LbSpacing.lg),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: l10n.compassHeadingSemantics(
                        so,
                        tenDai(l10n, huong),
                      ),
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          // Vạch mốc cố định = hướng mép trên màn hình.
                          CustomPaint(
                            size: const Size(20, 12),
                            painter: _VachMoc(tk.accentStrong),
                          ),
                          const SizedBox(height: LbSpacing.xxs),
                          _HoaGio(
                            phuongVi: h.phuongVi,
                            canh: canh,
                            chuBac: l10n.dirShortN,
                            mauHoa: mau.primary,
                            mauBac: tk.accentStrong,
                          ),
                          const SizedBox(height: LbSpacing.md),
                          // Số độ luôn một dòng: chữ hệ thống rất lớn thì
                          // thu nhỏ vừa bề ngang thay vì vỡ dòng.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: l10n.compassDegrees(so)),
                                  const TextSpan(text: '  '),
                                  TextSpan(
                                    text: tenNgan(l10n, huong),
                                    style: TextStyle(color: mau.primary),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              style: LbType.telemetryLarge.copyWith(
                                color: mau.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      l10n.compassMagneticNorth,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: LbSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: LbSpacing.xs,
                      runSpacing: LbSpacing.xs,
                      children: [
                        _Nhan(
                          cham: mauMuc,
                          chu: l10n.compassAccuracy(tenMuc(l10n, h.muc)),
                        ),
                        _Nhan(
                          chu: l10n.compassTilt(h.doc.round(), h.lan.round()),
                        ),
                      ],
                    ),
                    if (h.nhieuTu)
                      _CanhBao(
                        icon: LbIcons.khien,
                        noiDung: l10n.compassInterference,
                      )
                    else if (h.canHieuChuan)
                      _CanhBao(
                        icon: LbIcons.hieuChuanSo8,
                        noiDung: l10n.compassCalibrate,
                      ),
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

/// Hoa gió xoay ngược hướng máy để chữ Bắc luôn chỉ bắc từ.
class _HoaGio extends StatelessWidget {
  const new({
    required this.phuongVi,
    required this.canh,
    required this.chuBac,
    required this.mauHoa,
    required this.mauBac,
  });

  final double phuongVi;
  final double canh;
  final String chuBac;
  final Color mauHoa;
  final Color mauBac;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -doSangRad(phuongVi),
      child: SizedBox.square(
        dimension: canh,
        child: Stack(
          alignment: Alignment.center,
          children: [
            LbIcon(LbIcons.laBanHoaGio, size: canh * 0.72, color: mauHoa),
            Align(
              alignment: Alignment.topCenter,
              // Chữ là một phần hình vẽ: cỡ theo hoa gió, không theo cỡ chữ
              // hệ thống (đã có nhãn trình đọc màn hình ở trên).
              child: Text(
                chuBac,
                textScaler: TextScaler.noScaling,
                style: LbType.title.copyWith(
                  color: mauBac,
                  fontSize: canh * 0.11,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tam giác chỉ xuống - vạch mốc (lubber line) của la bàn.
class _VachMoc extends CustomPainter {
  new(this.mau);

  final Color mau;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = mau,
    );
  }

  @override
  bool shouldRepaint(_VachMoc old) => old.mau != mau;
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
  const new({required this.icon, required this.noiDung});

  final LbIconData icon;
  final String noiDung;

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
            child: Row(
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
          ),
        ),
      ),
    );
  }
}
