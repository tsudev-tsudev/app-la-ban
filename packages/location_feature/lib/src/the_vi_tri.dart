import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:location_feature/src/domain/doc_vi_tri.dart';
import 'package:location_feature/src/domain/toa_do.dart';
import 'package:location_feature/src/man_vi_tri.dart';
import 'package:location_feature/src/vi_tri_provider.dart';

/// Thẻ vị trí gọn dưới mặt la bàn: mời bật vị trí (just-in-time) hoặc hiện
/// toạ độ (chạm đổi định dạng, nhấn giữ để chép), địa giới, độ cao, sai số.
/// Chỉ dựng khi tab đang thấy -> GPS chỉ chạy lúc đó. Mỗi lần đọc được đẩy
/// sang vị trí dùng chung (bắc thực tự bật).
class TheViTri extends ConsumerStatefulWidget {
  const new({this.coVien = true, super.key});

  /// false: chỉ nội dung (nhúng trong thẻ khác).
  final bool coVien;

  @override
  ConsumerState<TheViTri> createState() => _TheViTriState();
}

class _TheViTriState extends ConsumerState<TheViTri> {
  late final AppLifecycleListener _vongDoi;

  @override
  void initState() {
    super.initState();
    // Người dùng có thể vừa bật quyền trong Cài đặt hệ thống.
    _vongDoi = AppLifecycleListener(
      onResume: () => ref.read(quyenViTriProvider.notifier).lamMoi().ignore(),
    );
  }

  @override
  void dispose() {
    _vongDoi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(docViTriProvider, (_, moi) {
      if (moi case AsyncData(:final value)) dayViTri(ref, value);
    });
    final quyen = ref.watch(quyenViTriProvider).value;
    final Widget than;
    if (quyen == null) {
      return const SizedBox.shrink();
    } else if (!quyen.duocPhep) {
      than = _LoiMoi(quyen: quyen);
    } else {
      than = switch (ref.watch(docViTriProvider)) {
        AsyncData(:final value) => _DangCo(
          d: value,
          xapXi: quyen == QuyenViTri.xapXi,
        ),
        _ => const _DangTim(),
      };
    }
    if (!widget.coVien) return than;
    return Card.outlined(
      margin: const EdgeInsets.only(top: LbSpacing.md),
      child: Padding(padding: const EdgeInsets.all(LbSpacing.md), child: than),
    );
  }
}

/// Mở màn chi tiết vị trí / telemetry (toàn màn, che thanh tab).
Future<void> moManViTri(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const ManViTri()));

class _LoiMoi extends ConsumerWidget {
  const new({required this.quyen});

  final QuyenViTri quyen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final han = quyen == QuyenViTri.tuChoiHan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LbIcon(LbIcons.ghimGps),
            const SizedBox(width: LbSpacing.sm),
            Expanded(child: Text(han ? l10n.locDeniedForever : l10n.locIntro)),
          ],
        ),
        const SizedBox(height: LbSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.tonal(
            onPressed: han
                ? () => ref.read(nguonViTriProvider).moCaiDatApp()
                : () => ref.read(quyenViTriProvider.notifier).xin(),
            child: Text(han ? l10n.locOpenSettings : l10n.locAllow),
          ),
        ),
      ],
    );
  }
}

/// Đã có quyền nhưng chưa có lần đọc: tìm vị trí, hoặc dịch vụ vị trí tắt.
class _DangTim extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tat = ref.watch(dichVuViTriProvider).value == false;
    return Row(
      children: [
        if (tat)
          const LbIcon(LbIcons.ghimGps)
        else
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        const SizedBox(width: LbSpacing.sm),
        Expanded(child: Text(tat ? l10n.locServiceOff : l10n.locSearching)),
        if (tat)
          TextButton(
            onPressed: () => ref.read(nguonViTriProvider).moCaiDatViTri(),
            child: Text(l10n.locOpenSettings),
          ),
      ],
    );
  }
}

/// Dịch vụ vị trí của máy có bật không (kiểm khi chờ lần đọc đầu).
final FutureProvider<bool> dichVuViTriProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(nguonViTriProvider).dichVuBat(),
);

class _DangCo extends ConsumerWidget {
  const new({required this.d, required this.xapXi});

  final DocViTri d;
  final bool xapXi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dinhDang = ref.watch(tuyChonViTriProvider.select((t) => t.dinhDang));
    final toaDo =
        dinhDangToaDo(dinhDang, d.viDo, d.kinhDo) ??
        dinhDangDD(d.viDo, d.kinhDo);
    final dg = ref.watch(diaGioiProvider);
    final tiengViet = Localizations.localeOf(context).languageCode == 'vi';
    final geoid = ref.watch(taiNguyenViTriProvider).value?.geoid;
    final cao = doCaoMucBien(d, geoid);
    final noiDung = [
      if (dg != null)
        [
          dg.tenXa(tiengViet: tiengViet),
          dg.tenTinh(tiengViet: tiengViet),
        ].nonNulls.join(', ')
      else if (ref.watch(taiNguyenViTriProvider).hasValue)
        l10n.locOutsideVn,
      [
        if (cao != null) l10n.locAltitude(cao.round()),
        if (d.doChinhXacNgang case final a?) l10n.locAccuracy(a.round()),
        if (xapXi) l10n.locApproximate,
      ].join(' · '),
    ].where((s) => s.isNotEmpty);
    void doi() {
      const ds = DinhDangToaDo.values;
      ref
          .read(tuyChonViTriProvider.notifier)
          .datDinhDang(ds[(dinhDang.index + 1) % ds.length]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          hint: l10n.locCycleFormat,
          child: InkWell(
            borderRadius: BorderRadius.circular(LbRadius.sm),
            onTap: doi,
            onLongPress: () => _chep(context, toaDo),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: LbSpacing.xxs),
              child: Row(
                children: [
                  const LbIcon(LbIcons.ghimGps, size: 20),
                  const SizedBox(width: LbSpacing.xs),
                  Expanded(
                    child: Text(
                      toaDo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final s in noiDung)
          Padding(
            padding: const EdgeInsets.only(top: LbSpacing.xxs),
            child: Text(s, style: theme.textTheme.bodySmall),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => moManViTri(context),
            child: Text(l10n.locDetails),
          ),
        ),
      ],
    );
  }
}

void _chep(BuildContext context, String s) {
  Clipboard.setData(ClipboardData(text: s)).ignore();
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(context.l10n.locCopied)));
}

/// Chép chuỗi + báo (dùng chung với màn chi tiết).
void chepToaDo(BuildContext context, String s) => _chep(context, s);
