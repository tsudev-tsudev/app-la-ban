import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:waypoint_feature/src/domain/diem_moc.dart';
import 'package:waypoint_feature/src/du_lieu/kho_diem.dart';
import 'package:waypoint_feature/src/hien_thi.dart';
import 'package:waypoint_feature/src/icon_diem.dart';
import 'package:waypoint_feature/src/man_chia_se.dart';
import 'package:waypoint_feature/src/man_dan_duong.dart';
import 'package:waypoint_feature/src/man_diem.dart';
import 'package:waypoint_feature/src/man_sua_diem.dart';
import 'package:waypoint_feature/src/nghe_anh_diem.dart';
import 'package:waypoint_feature/src/providers.dart';

/// Chi tiết một điểm: toạ độ, ảnh, ghi chú; dẫn đường / chia sẻ / sửa / xoá.
class ManChiTietDiem extends ConsumerWidget {
  const new({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = diemTheoId(ref, id);
    if (d == null) {
      // Vừa xoá / đang nạp.
      return Scaffold(appBar: AppBar());
    }
    final chu = Theme.of(context).textTheme;
    final phu = Theme.of(context).colorScheme.onSurfaceVariant;
    final toaDo = ref.watch(dinhDangToaDoDiemProvider)(d.viDo, d.kinhDo);
    final chiaSe = ref.watch(choPhepChiaSeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(d.ten, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const ValueKey('sua-diem'),
            tooltip: l.wpEdit,
            icon: const LbIcon(IconDiem.sua),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ManSuaDiem(diem: d)),
            ),
          ),
          IconButton(
            key: const ValueKey('xoa-diem'),
            tooltip: l.wpDelete,
            icon: const LbIcon(IconDiem.xoa),
            onPressed: () => _xoa(context, ref, d),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(LbSpacing.md),
              children: [
                Text(d.ten, style: chu.headlineSmall),
                const SizedBox(height: LbSpacing.md),
                Text(l.wpCoords, style: chu.labelLarge?.copyWith(color: phu)),
                Row(
                  children: [
                    Expanded(child: ChuChonDuoc(toaDo, style: chu.bodyLarge)),
                    IconButton(
                      tooltip: l.wpCopyCoords,
                      icon: const LbIcon(IconDiem.saoChep),
                      onPressed: () => saoChep(
                        context,
                        '${d.viDo.toStringAsFixed(7)}, '
                        '${d.kinhDo.toStringAsFixed(7)}',
                      ),
                    ),
                  ],
                ),
                if (d.caoDo != null)
                  Text(
                    l.wpAltValue(double.parse(d.caoDo!.toStringAsFixed(1))),
                    style: chu.bodyMedium,
                  ),
                Text(
                  l.wpCreated(ngayGio(context, ref, d.taoLuc)),
                  style: chu.bodyMedium?.copyWith(color: phu),
                ),
                if (d.ghiChu.isNotEmpty) ...[
                  const SizedBox(height: LbSpacing.md),
                  Text(l.wpNote, style: chu.labelLarge?.copyWith(color: phu)),
                  ChuChonDuoc(d.ghiChu, style: chu.bodyLarge),
                ],
                NgheAnhDiem(
                  id: id,
                  builder: (context, anh) => anh.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: LbSpacing.md),
                            Text(
                              l.wpPhotos,
                              style: chu.labelLarge?.copyWith(color: phu),
                            ),
                            const SizedBox(height: LbSpacing.xs),
                            Wrap(
                              spacing: LbSpacing.xs,
                              runSpacing: LbSpacing.xs,
                              children: [
                                for (final (i, a) in anh.indexed)
                                  _AnhBam(
                                    anh: a,
                                    nhan: l.wpPhotoSemantics(i + 1),
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: LbSpacing.lg),
                Wrap(
                  spacing: LbSpacing.sm,
                  runSpacing: LbSpacing.sm,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('dan-duong'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ManDanDuong(
                            ten: d.ten,
                            viDo: d.viDo,
                            kinhDo: d.kinhDo,
                          ),
                        ),
                      ),
                      icon: const LbIcon(IconDiem.muiTen),
                      label: Text(l.wpNavigate),
                    ),
                    if (chiaSe)
                      OutlinedButton.icon(
                        key: const ValueKey('chia-se'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ManChiaSe(diem: d),
                          ),
                        ),
                        icon: const LbIcon(LbIcons.chiaSeQr),
                        label: Text(l.wpShare),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _xoa(BuildContext context, WidgetRef ref, DiemMoc d) async {
    final l = context.l10n;
    final dongY = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.wpDeleteConfirm(d.ten)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(l.wpCancel),
          ),
          TextButton(
            key: const ValueKey('xac-nhan-xoa'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.wpDelete),
          ),
        ],
      ),
    );
    if (dongY != true) return;
    await ref.read(khoDiemProvider)?.xoa(d.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _AnhBam extends StatelessWidget {
  const new({required this.anh, required this.nhan});

  final AnhDiemMoc anh;
  final String nhan;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(LbRadius.sm),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.memory(anh.duLieu, semanticLabel: nhan)),
          ),
        ),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(LbRadius.sm),
      child: Image.memory(
        anh.duLieu,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        cacheWidth: 360,
        semanticLabel: nhan,
      ),
    ),
  );
}
