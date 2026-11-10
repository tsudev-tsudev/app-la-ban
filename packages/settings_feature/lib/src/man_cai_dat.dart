import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:settings_feature/src/cai_dat_provider.dart';
import 'package:settings_feature/src/domain/cai_dat.dart';
import 'package:settings_feature/src/man_quyen_rieng_tu.dart';

/// Tab Cài đặt: ngôn ngữ, giao diện, quyền riêng tư, giấy phép, phiên bản.
class ManCaiDat extends ConsumerWidget {
  const new({required this.phienBan, this.mucPro, super.key});

  /// Chuỗi phiên bản app (do app truyền vào, ví dụ `0.1.0+1`).
  final String phienBan;

  /// Mục "La bàn Pro" (M1a) - app nối (tính năng không gọi nhau).
  final Widget? mucPro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ngonNgu = ref.watch(caiDatProvider.select((c) => c.ngonNgu));
    final cheDo = ref.watch(caiDatProvider.select((c) => c.cheDo));
    final tb = ref.read(caiDatProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: LbSpacing.xs),
        children: [
          _TieuDeMuc(l10n.settingsLanguage),
          RadioGroup<LuaChonNgonNgu>(
            groupValue: ngonNgu,
            onChanged: (v) => tb.datNgonNgu(v!),
            child: Column(
              children: [
                for (final (v, ten) in [
                  (LuaChonNgonNgu.heThong, l10n.optionSystem),
                  (LuaChonNgonNgu.vi, l10n.languageVietnamese),
                  (LuaChonNgonNgu.en, l10n.languageEnglish),
                ])
                  RadioListTile<LuaChonNgonNgu>(
                    key: ValueKey('ngon-ngu-${v.name}'),
                    value: v,
                    title: Text(ten),
                  ),
              ],
            ),
          ),
          const Divider(),
          _TieuDeMuc(l10n.settingsTheme),
          RadioGroup<CheDoGiaoDien>(
            groupValue: cheDo,
            onChanged: (v) => tb.datCheDo(v!),
            child: Column(
              children: [
                for (final (v, ten) in [
                  (CheDoGiaoDien.sang, l10n.themeLight),
                  (CheDoGiaoDien.toi, l10n.themeDark),
                  (CheDoGiaoDien.heThong, l10n.optionSystem),
                ])
                  RadioListTile<CheDoGiaoDien>(
                    key: ValueKey('che-do-${v.name}'),
                    value: v,
                    title: Text(ten),
                  ),
              ],
            ),
          ),
          const Divider(),
          ?mucPro,
          ListTile(
            key: const ValueKey('quyen-rieng-tu'),
            title: Text(l10n.settingsPrivacy),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ManQuyenRiengTu()),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: phienBan,
            ),
          ),
          ListTile(
            title: Text(
              l10n.settingsVersion(phienBan),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TieuDeMuc extends StatelessWidget {
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
