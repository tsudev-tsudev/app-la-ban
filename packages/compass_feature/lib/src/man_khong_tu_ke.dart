import 'dart:math' as math;

import 'package:compass_feature/src/man_la_ban.dart';
import 'package:compass_feature/src/man_thiet_bi.dart';
import 'package:compass_feature/src/mat_la_ban.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:sensors/sensors.dart';

/// Tên nguồn hướng để hiển thị ("Mặt Trời + con quay"...).
String tenNguonHuong(LbL10n l, HuongUocLuong u) {
  final goc = switch (u.nguon) {
    NguonChiHuong.tuKe => l.a9SrcCompass,
    NguonChiHuong.gps => l.a9SrcGps,
    NguonChiHuong.matTroi => l.a9SrcSun,
    NguonChiHuong.matTrang => l.a9SrcMoon,
    NguonChiHuong.thuCong => l.a9SrcManual,
  };
  return u.theoConQuay ? l.a9SrcWithGyro(goc) : goc;
}

/// La bàn khi máy KHÔNG có từ kế (A9a, Q59): chuỗi nguồn GPS course >
/// Mặt Trời / Mặt Trăng / tự đặt (+ con quay giữ hướng). Mặt số hiện nguồn
/// đang dùng + sai số + hướng dẫn.
class ManKhongTuKe extends ConsumerWidget {
  const new({this.theDuoi, super.key});

  /// Thẻ bên dưới (vị trí) - cũng là nơi đẩy GPS vào chuỗi nguồn.
  final Widget? theDuoi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final u = ref.watch(huongDaNguonProvider);
    final neo = ref.watch(neoHuongProvider);
    final canNeoLai = ref.watch(canNeoLaiProvider);
    final tt = ref.watch(thienTheDungDuocProvider);
    final dangDi = ref.watch(huongGpsProvider) != null;
    final nhe = ref.watch(cheDoNheProvider);
    final nl = ref.watch(nangLucProvider);
    final khongConQuay = nl != null && !giuHuongDuoc(nl);
    return LayoutBuilder(
      builder: (context, rang) {
        final canh = math.min(
          rang.maxWidth - 2 * LbSpacing.lg,
          rang.maxHeight * 0.45,
        );
        final ghiChu = [
          if (canNeoLai) (l10n.a9Reanchor, true),
          if (khongConQuay && neo != null && u?.nguon == neo.goc.nguon)
            (l10n.a9StaticAnchor, false),
          if (dangDi) (l10n.a9Walking, false),
          if (!tt.matTroi && !tt.matTrang) (l10n.a9SkyLow, false),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(LbSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (u != null) ...[
                    Semantics(
                      label: l10n.compassHeadingSemantics(
                        u.phuongVi.round() % 360,
                        tenDai(l10n, huongChinh(u.phuongVi)),
                      ),
                      excludeSemantics: true,
                      child: MatLaBan(
                        phuongVi: u.phuongVi,
                        canh: math.max(120, math.min(380, canh)),
                        nhan8: [
                          for (final c in HuongChinh.values) tenNgan(l10n, c),
                        ],
                        mau: MauMatLaBan.tuTheme(context),
                        nhe: nhe,
                      ),
                    ),
                    const SizedBox(height: LbSpacing.md),
                    ExcludeSemantics(
                      child: Text(
                        '${u.phuongVi.round() % 360}°  '
                        '${tenNgan(l10n, huongChinh(u.phuongVi))}',
                        style: LbType.telemetryLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      l10n.a9SrcLine(tenNguonHuong(l10n, u), u.saiSoDo.round()),
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    LbIcon(
                      LbIcons.laBanHoaGio,
                      size: 96,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: LbSpacing.sm),
                    Text(
                      l10n.a9NoMagTitle,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: LbSpacing.sm),
                  Text(
                    l10n.a9NoMagBody,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  for (final (chu, canhBao) in ghiChu)
                    Padding(
                      padding: const EdgeInsets.only(top: LbSpacing.xs),
                      child: Text(
                        chu,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: canhBao ? theme.colorScheme.error : null,
                        ),
                      ),
                    ),
                  const SizedBox(height: LbSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: LbSpacing.sm,
                    runSpacing: LbSpacing.sm,
                    children: [
                      FilledButton.tonal(
                        onPressed: tt.matTroi
                            ? () => _hoiThienThe(context, ref, matTrang: false)
                            : null,
                        child: Text(l10n.a9BtnSun),
                      ),
                      FilledButton.tonal(
                        onPressed: tt.matTrang
                            ? () => _hoiThienThe(context, ref, matTrang: true)
                            : null,
                        child: Text(l10n.a9BtnMoon),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _hoiThuCong(context, ref, u),
                        child: Text(l10n.a9BtnManual),
                      ),
                      TextButton(
                        onPressed: () => moThietBi(context),
                        child: Text(l10n.a9BtnDevice),
                      ),
                    ],
                  ),
                  if (theDuoi != null) ...[
                    const SizedBox(height: LbSpacing.md),
                    theDuoi!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _hoiThienThe(
  BuildContext context,
  WidgetRef ref, {
  required bool matTrang,
}) async {
  final l10n = context.l10n;
  final dongY = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(matTrang ? l10n.a9BtnMoon : l10n.a9BtnSun),
      content: Text(matTrang ? l10n.a9MoonHelp : l10n.a9SunHelp),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(MaterialLocalizations.of(c).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(l10n.a9BtnSet),
        ),
      ],
    ),
  );
  if (dongY != true) return;
  final ok = ref
      .read(neoHuongProvider.notifier)
      .neoThienThe(matTrang: matTrang);
  if (!ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.a9SetFailed)));
  }
}

Future<void> _hoiThuCong(
  BuildContext context,
  WidgetRef ref,
  HuongUocLuong? hienTai,
) async {
  final l10n = context.l10n;
  var goc = (hienTai?.phuongVi ?? 0).roundToDouble() % 360;
  final dongY = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, datLai) => AlertDialog(
        title: Text(l10n.a9BtnManual),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.a9ManualHelp),
            const SizedBox(height: LbSpacing.md),
            Text(
              '${goc.round()}°  ${tenNgan(l10n, huongChinh(goc))}',
              style: Theme.of(c).textTheme.headlineSmall,
            ),
            Slider(
              value: goc,
              max: 359,
              divisions: 359,
              label: '${goc.round()}°',
              onChanged: (v) => datLai(() => goc = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(MaterialLocalizations.of(c).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.a9BtnSet),
          ),
        ],
      ),
    ),
  );
  if (dongY == true) ref.read(neoHuongProvider.notifier).neoThuCong(goc);
}
