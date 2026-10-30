import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:waypoint_feature/src/providers.dart';

/// Thẻ trạng thái GPS trong màn sửa điểm: xin quyền / đang chờ / sai số +
/// nút điền vị trí hiện tại.
class TheViTriDiem extends ConsumerWidget {
  const new({required this.onDung, this.dangCho = false, super.key});

  final ValueChanged<ViTriHienTai> onDung;

  /// Đang chờ lần đọc đầu để tự điền.
  final bool dangCho;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final chu = Theme.of(context).textTheme;
    final v = ref.watch(viTriDiemProvider);
    final Widget noiDung = switch (v) {
      ViTriChuaCoQuyen() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.wpLocationNeeded, style: chu.bodyMedium),
          const SizedBox(height: LbSpacing.xs),
          OutlinedButton(
            key: const ValueKey('xin-vi-tri'),
            onPressed: () => ref.read(xinQuyenViTriDiemProvider)(),
            child: Text(l.wpGrant),
          ),
        ],
      ),
      ViTriDangCho() => Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: LbSpacing.sm),
          Expanded(child: Text(l.wpLocating, style: chu.bodyMedium)),
        ],
      ),
      ViTriCo(:final viTri) => Wrap(
        spacing: LbSpacing.sm,
        runSpacing: LbSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (viTri.saiSoM != null)
            Text(l.wpAccuracy(viTri.saiSoM!.round()), style: chu.bodyMedium),
          OutlinedButton.icon(
            key: const ValueKey('dung-vi-tri'),
            onPressed: () => onDung(viTri),
            icon: const LbIcon(LbIcons.ghimGps),
            label: Text(l.wpUseCurrent),
          ),
        ],
      ),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(LbSpacing.sm),
        child: noiDung,
      ),
    );
  }
}
