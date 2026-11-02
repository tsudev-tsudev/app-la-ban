import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:settings_feature/src/cai_dat_provider.dart';
import 'package:settings_feature/src/domain/xuat_du_lieu.dart';
import 'package:settings_feature/src/hanh_dong_rieng_tu.dart';
import 'package:settings_feature/src/thong_bao_du_lieu.dart';

/// Số điểm mốc đang lưu (null khi app không nối / đang đọc).
final FutureProvider<int?> _soDiemProvider = FutureProvider.autoDispose<int?>((
  ref,
) async {
  final dem = ref.watch(hanhDongRiengTuProvider).demDiem;
  return dem == null ? null : await dem();
});

/// Màn Quyền riêng tư (A8a, QUYET_DINH Q43): xem lại thông báo, bật / rút
/// đồng ý gửi dữ liệu bảo mật, xuất / xoá dữ liệu trên máy, mã thiết bị +
/// yêu cầu xoá phía máy chủ, lối tắt thu hồi quyền hệ thống.
class ManQuyenRiengTu extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chu = Theme.of(context).textTheme;
    final hd = ref.watch(hanhDongRiengTuProvider);
    final dongY = ref.watch(caiDatProvider.select((c) => c.dongY));
    final trucTuyen = ref.watch(caiDatProvider.select((c) => c.trucTuyen));
    final baoLoi = ref.watch(caiDatProvider.select((c) => c.baoLoi));
    final soDiem = ref.watch(_soDiemProvider).value;
    final ma = hd.maThietBi?.call();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacy)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: LbSpacing.xs),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: LbSpacing.md),
            child: ThongBaoDuLieu(),
          ),
          const Divider(),
          SwitchListTile(
            key: const ValueKey('truc-tuyen'),
            value: trucTuyen,
            onChanged: (v) =>
                ref.read(caiDatProvider.notifier).datDongY(trucTuyen: v),
            title: Text(l10n.privacyOnline),
            subtitle: Text(
              [
                l10n.privacyOnlineHint,
                if (dongY != null)
                  l10n.privacyChoiceAt(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(dongY.luc.toLocal()),
                  ),
              ].join('\n'),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('bao-loi'),
            value: trucTuyen && baoLoi,
            onChanged: trucTuyen
                ? (v) => ref.read(caiDatProvider.notifier).datBaoLoi(bat: v)
                : null,
            title: Text(l10n.privacyCrash),
            subtitle: Text(
              trucTuyen ? l10n.privacyCrashHint : l10n.privacyCrashNeedsOnline,
            ),
          ),
          const Divider(),
          _TieuDe(l10n.privacyOnDevice),
          if (soDiem != null)
            ListTile(
              leading: const LbIcon(LbIcons.diemMoc),
              title: Text(l10n.privacyWaypoints(soDiem)),
            ),
          if (hd.xuatDuLieu case final xuat?)
            ListTile(
              key: const ValueKey('xuat'),
              title: Text(l10n.privacyExport),
              onTap: () async {
                final ok = await xuat();
                if (context.mounted) {
                  _bao(
                    context,
                    ok ? l10n.privacyExportDone : l10n.privacyExportFailed,
                  );
                }
              },
            ),
          if (hd.xoaToanBo case final xoa?)
            ListTile(
              key: const ValueKey('xoa-het'),
              title: Text(
                l10n.privacyDeleteAll,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                if (await _xacNhanXoa(context)) await xoa();
              },
            ),
          const Divider(),
          _TieuDe(l10n.privacyOnServer),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LbSpacing.md),
            child: Text(l10n.privacyServerBody, style: chu.bodyMedium),
          ),
          ListTile(
            key: const ValueKey('ma-thiet-bi'),
            leading: const LbIcon(LbIcons.khien),
            title: Text(
              ma == null ? l10n.privacyNoDeviceId : l10n.privacyDeviceId(ma),
            ),
            onTap: ma == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: ma));
                    if (context.mounted) _bao(context, l10n.privacyCopied);
                  },
          ),
          if (hd.moLienKet case final mo?)
            ListTile(
              key: const ValueKey('yeu-cau-xoa'),
              title: Text(l10n.privacyRequestDelete),
              onTap: () async {
                final ok = await mo(
                  thuYeuCauXoa(
                    chuDe: l10n.privacyRequestSubject,
                    noiDung: l10n.privacyRequestBody(ma ?? '-'),
                  ),
                );
                if (!ok && context.mounted) {
                  _bao(context, l10n.privacyMailFailed(thuRiengTu));
                }
              },
            ),
          if (hd.moCaiDatHeThong case final moCaiDat?) ...[
            const Divider(),
            _TieuDe(l10n.privacyPermissions),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LbSpacing.md),
              child: Text(l10n.privacyPermissionsBody, style: chu.bodyMedium),
            ),
            ListTile(
              key: const ValueKey('cai-dat-he-thong'),
              leading: const LbIcon(LbIcons.caiDat),
              title: Text(l10n.privacyOpenSettings),
              onTap: moCaiDat,
            ),
          ],
        ],
      ),
    );
  }
}

void _bao(BuildContext context, String s) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(s)));

Future<bool> _xacNhanXoa(BuildContext context) async {
  final l10n = context.l10n;
  final kq = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.privacyDeleteTitle),
      content: Text(l10n.privacyDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(l10n.wpCancel),
        ),
        TextButton(
          key: const ValueKey('xac-nhan-xoa'),
          onPressed: () => Navigator.pop(c, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(c).colorScheme.error,
          ),
          child: Text(l10n.privacyDeleteConfirm),
        ),
      ],
    ),
  );
  return kq ?? false;
}

class _TieuDe extends StatelessWidget {
  const new(this.chu);

  final String chu;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LbSpacing.md,
      LbSpacing.md,
      LbSpacing.md,
      LbSpacing.xxs,
    ),
    child: Semantics(
      header: true,
      child: Text(
        chu,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}
