import 'package:compass_feature/src/man_khong_tu_ke.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:sensors/sensors.dart';

/// Mở màn "Thiết bị của bạn".
Future<void> moThietBi(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const ManThietBi()));

/// "Thiết bị của bạn" (A9a): cảm biến có / không, nguồn hướng dùng được theo
/// thứ tự, chế độ nhẹ. Không đọc / hiện định danh phần cứng.
class ManThietBi extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final n = ref.watch(nangLucProvider);
    final nhe = ref.watch(cheDoNheProvider);
    String tenNguon(NguonChiHuong g) => tenNguonHuong(l10n, (
      phuongVi: 0,
      bacThuc: true,
      nguon: g,
      saiSoDo: 0,
      theoConQuay:
          n != null &&
          giuHuongDuoc(n) &&
          g != NguonChiHuong.tuKe &&
          g != NguonChiHuong.gps,
    ));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.a9DeviceTitle)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(LbSpacing.md),
              children: [
                Text(l10n.a9DeviceIntro, style: theme.textTheme.bodyMedium),
                const SizedBox(height: LbSpacing.sm),
                if (n == null)
                  Text(l10n.a9DeviceProbing)
                else ...[
                  for (final (ten, co) in [
                    (l10n.a9SensMag, n.tuKe),
                    (l10n.a9SensGyro, n.conQuay),
                    (l10n.a9SensAccel, n.giaToc),
                    (l10n.a9SensGameRot, n.xoayGame),
                    (l10n.a9SensBaro, n.khiAp),
                    (l10n.a9SensGps, n.gps),
                    (l10n.a9SensCamera, n.camera),
                  ])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(ten),
                      trailing: Text(
                        co ? l10n.a9Yes : l10n.a9No,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: co
                              ? LbThemeExt.of(context).colors.successStrong
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const Divider(),
                  Text(l10n.a9SourcesTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: LbSpacing.xs),
                  for (final (i, g) in nguonKhaDung(n).indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: LbSpacing.xs,
                      ),
                      child: Text('${i + 1}. ${tenNguon(g)}'),
                    ),
                  const Divider(),
                  Text(
                    nhe ? l10n.a9LiteOn : l10n.a9LiteOff,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
