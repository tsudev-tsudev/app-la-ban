import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:i18n/i18n.dart';

/// Tab La bàn. Mặt la bàn thật (CustomPainter + cảm biến) thay vào ở A2-A3.
class ManLaBan extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabCompass)),
      body: LayoutBuilder(
        builder: (context, rang) => LbTrangTrong(
          hinh: LbLogo(
            size: math.min(200, rang.biggest.shortestSide * 0.4),
            semanticLabel: l10n.logoLabel,
          ),
          moTa: l10n.compassPlaceholder,
        ),
      ),
    );
  }
}
