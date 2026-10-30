import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:settings_feature/src/domain/dong_y.dart';
import 'package:settings_feature/src/hanh_dong_rieng_tu.dart';

/// Thông báo xử lý dữ liệu (NĐ 13/2023 Điều 13): dữ liệu gì, ở đâu, gửi cho
/// ai, lưu bao lâu, quyền của người dùng + liên kết chính sách đầy đủ. Dùng ở
/// màn giới thiệu (trước khi chọn) và đầu màn Quyền riêng tư (xem lại).
/// Nội dung đổi -> tăng [banThongBaoDuLieu].
class ThongBaoDuLieu extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chu = Theme.of(context).textTheme;
    final mo = ref.watch(hanhDongRiengTuProvider).moLienKet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.noticeTitle, style: chu.titleMedium),
        ),
        const SizedBox(height: LbSpacing.sm),
        for (final y in [
          l10n.noticeDevice,
          l10n.noticeSensors,
          l10n.noticeSecurity,
          l10n.noticeRetention,
          l10n.noticeRights,
        ])
          _Y(y),
        if (mo != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('chinh-sach'),
              onPressed: () => mo(urlChinhSach(l10n.localeName)),
              child: Text(l10n.noticePolicy),
            ),
          ),
      ],
    );
  }
}

/// Một ý: chấm đầu dòng (ẩn với trình đọc màn hình) + chữ.
class _Y extends StatelessWidget {
  const new(this.chu);

  final String chu;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final co = t.textTheme.bodyMedium;
    final cao = (co?.fontSize ?? 14) * (co?.height ?? 1.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: LbSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: LbSpacing.md,
              height: MediaQuery.textScalerOf(context).scale(cao),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: t.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: Text(chu, style: co)),
        ],
      ),
    );
  }
}
