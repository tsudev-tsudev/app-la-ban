import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:map_feature/src/domain/ban_do.dart';
import 'package:map_feature/src/du_lieu/vung_offline.dart';
import 'package:map_feature/src/icon_ban_do.dart';
import 'package:map_feature/src/providers.dart';

/// Danh sách vùng đã tải + dung lượng (đọc lại sau mỗi lần tải / xoá).
final FutureProvider<({List<VungOffline> ds, int? byte})> dsVungProvider =
    FutureProvider.autoDispose<({List<VungOffline> ds, int? byte})>((
      ref,
    ) async {
      final kho = ref.watch(khoVungOfflineProvider);
      return (ds: await kho.danhSach(), byte: await kho.dungLuong());
    });

/// Tải một vùng theo style đang dùng (sáng / tối + ngôn ngữ của [context]),
/// lưu kèm các style còn lại. Dùng chung cho màn này và màn nhập dữ liệu của
/// La bàn Pro (M2b - tải lại vùng chuyển từ bản miễn phí).
Stream<TienDoTai> taiVung(
  BuildContext context,
  WidgetRef ref, {
  required String ten,
  required KhungBanDo khung,
  required int zMin,
  required int zMax,
  required bool tongQuan,
}) {
  final goc = ref.read(gocBanDoProvider);
  final toi = Theme.of(context).brightness == Brightness.dark;
  final nn = Localizations.localeOf(context).languageCode;
  final url = urlKieuBanDo(goc, toi: toi, ngonNgu: nn);
  return ref
      .read(khoVungOfflineProvider)
      .tai(
        ten: ten,
        khung: khung,
        zMin: zMin,
        zMax: zMax,
        urlKieu: url,
        urlKieuPhu: [
          for (final u in moiUrlKieu(goc))
            if (u != url) u,
        ],
        tongQuan: tongQuan,
        taoLuc: ref.read(gioBanDoProvider)(),
      );
}

/// Màn "Bản đồ ngoại tuyến": tải gói tổng quan cả nước / vùng đang xem, xem
/// dung lượng, xoá vùng.
class ManVungOffline extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ManVungOffline> createState() => _ManVungOfflineState();
}

class _ManVungOfflineState extends ConsumerState<ManVungOffline> {
  /// Mục đang tải ('tong-quan' / 'dang-xem') + tiến độ.
  String? _dangTai;
  TienDoTai? _tienDo;
  StreamSubscription<TienDoTai>? _sub;

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _tai(
    String muc, {
    required String ten,
    required KhungBanDo khung,
    required int zMin,
    required int zMax,
  }) {
    final l10n = context.l10n;
    final tb = ScaffoldMessenger.of(context);
    void bao(String s) => tb
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
    var coLoi = false;
    setState(() {
      _dangTai = muc;
      _tienDo = null;
    });
    _sub =
        taiVung(
          context,
          ref,
          ten: ten,
          khung: khung,
          zMin: zMin,
          zMax: zMax,
          tongQuan: muc == 'tong-quan',
        ).listen(
          (t) {
            if (mounted) setState(() => _tienDo = t);
          },
          onError: (Object _) {
            coLoi = true;
            bao(l10n.mapOfflineFailed);
          },
          onDone: () {
            if (!mounted) return;
            setState(() => _dangTai = null);
            ref.invalidate(dsVungProvider);
            if (!coLoi) bao(l10n.mapOfflineDone);
          },
        );
  }

  Future<void> _xoa(VungOffline v, String ten) async {
    final l10n = context.l10n;
    final dongY = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.mapOfflineDeleteTitle(ten)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(l10n.wpCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l10n.wpDelete),
          ),
        ],
      ),
    );
    if (dongY != true) return;
    await ref.read(khoVungOfflineProvider).xoa(v.id);
    ref.invalidate(dsVungProvider);
  }

  String _ngay(int ms) {
    final d = ref.read(gioDiaPhuongBanDoProvider)(ms);
    String hai(int v) => v.toString().padLeft(2, '0');
    return '${hai(d.day)}/${hai(d.month)}/${d.year} ${hai(d.hour)}:${hai(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kieu = Theme.of(context).textTheme;
    final mau = Theme.of(context).colorScheme;
    final xem = ref.watch(khungDangXemProvider);
    final zXem = xem == null ? 0 : zoomBatDauVung(xem.zoom);
    final soTile = xem == null ? 0 : soTileVung(xem.khung, zXem, zoomTileToiDa);
    final dsVung = ref.watch(dsVungProvider);

    Widget tienDo(String muc) {
      if (_dangTai != muc) return const SizedBox.shrink();
      final t = _tienDo;
      return Padding(
        padding: const EdgeInsets.only(top: LbSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: t == null || t.tong == 0 ? null : t.daXong / t.tong,
            ),
            if (t != null && t.tong > 0)
              Padding(
                padding: const EdgeInsets.only(top: LbSpacing.xs),
                child: Text(
                  l10n.mapOfflineDownloading(t.daXong, t.tong),
                  style: kieu.bodySmall,
                ),
              ),
          ],
        ),
      );
    }

    Widget muc({
      required String id,
      required String tieuDe,
      required String moTa,
      required VoidCallback? onTai,
    }) => Card(
      child: Padding(
        padding: const EdgeInsets.all(LbSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tieuDe, style: kieu.titleMedium),
            const SizedBox(height: LbSpacing.xs),
            Text(
              moTa,
              style: kieu.bodyMedium?.copyWith(color: mau.onSurfaceVariant),
            ),
            const SizedBox(height: LbSpacing.md),
            FilledButton.icon(
              onPressed: _dangTai == null ? onTai : null,
              icon: const LbIcon(IconBanDo.taiVe),
              label: Text(l10n.mapOfflineDownload),
            ),
            tienDo(id),
          ],
        ),
      ),
    );

    final quaRong = soTile > tileToiDaMotVung;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapOffline)),
      body: ListView(
        padding: const EdgeInsets.all(LbSpacing.lg),
        children: [
          Text(l10n.mapOfflineIntro, style: kieu.bodyMedium),
          const SizedBox(height: LbSpacing.lg),
          muc(
            id: 'tong-quan',
            tieuDe: l10n.mapOfflineOverview,
            moTa: l10n.mapOfflineOverviewDesc,
            onTai: () => _tai(
              'tong-quan',
              ten: l10n.mapOfflineOverview,
              khung: khungVietNam,
              zMin: 0,
              zMax: zoomTongQuan,
            ),
          ),
          const SizedBox(height: LbSpacing.md),
          muc(
            id: 'dang-xem',
            tieuDe: l10n.mapOfflineCurrent,
            moTa: xem == null || soTile == 0
                ? l10n.mapOfflineNoView
                : quaRong
                ? l10n.mapOfflineTooLarge(soTile)
                : l10n.mapOfflineCurrentDesc(soTile),
            onTai: xem == null || soTile == 0 || quaRong
                ? null
                : () => _tai(
                    'dang-xem',
                    ten: l10n.mapOfflineAreaName(
                      _ngay(ref.read(gioBanDoProvider)()),
                    ),
                    khung: xem.khung,
                    zMin: zXem,
                    zMax: zoomTileToiDa,
                  ),
          ),
          const SizedBox(height: LbSpacing.xl),
          Text(l10n.mapOfflineSaved, style: kieu.titleMedium),
          ...switch (dsVung) {
            AsyncData(:final value) => [
              if (value.byte != null)
                Padding(
                  padding: const EdgeInsets.only(top: LbSpacing.xs),
                  child: Text(
                    l10n.mapOfflineStorage(value.byte! / 1e6),
                    style: kieu.bodySmall,
                  ),
                ),
              if (value.ds.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: LbSpacing.sm),
                  child: Text(l10n.mapOfflineEmpty),
                ),
              for (final v in value.ds)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(v.tongQuan ? l10n.mapOfflineOverview : v.ten),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.mapOfflineZoom(v.zMin, v.zMax)),
                      Text(_ngay(v.taoLuc)),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: l10n.mapOfflineDelete,
                    icon: const LbIcon(IconBanDo.xoa),
                    onPressed: _dangTai == null
                        ? () => _xoa(
                            v,
                            v.tongQuan ? l10n.mapOfflineOverview : v.ten,
                          )
                        : null,
                  ),
                ),
            ],
            AsyncError() => [Text(l10n.mapOfflineEmpty)],
            _ => [const LinearProgressIndicator()],
          },
        ],
      ),
    );
  }
}
