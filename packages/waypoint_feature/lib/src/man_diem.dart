import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:i18n/i18n.dart';

/// Tab Điểm (điểm mốc đã lưu). Danh sách thật + chia sẻ ở A6.
class ManDiem extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabWaypoints)),
      body: LbTrangTrong(
        hinh: LbIcon(
          LbIcons.diemMoc,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        tieuDe: l10n.waypointsEmptyTitle,
        moTa: l10n.waypointsEmptyBody,
      ),
    );
  }
}
