import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:i18n/i18n.dart';

/// Tab Bản đồ. MapLibre + tile offline thay vào ở A7.
class ManBanDo extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMap)),
      body: LbTrangTrong(
        hinh: LbIcon(
          LbIcons.banDo,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        moTa: l10n.mapPlaceholder,
      ),
    );
  }
}
