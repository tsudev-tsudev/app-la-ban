import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:settings_feature/settings_feature.dart';

/// Màn giới thiệu lần đầu: logo động (cùng biểu tượng với splash native ->
/// chuyển mượt), một câu giới thiệu, nút bắt đầu.
class ManGioiThieu extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, rang) => LbTrangTrong(
                  hinh: LbLogoDong(
                    size: math.min(160, rang.biggest.shortestSide * 0.4),
                    semanticLabel: l10n.logoLabel,
                  ),
                  tieuDe: l10n.onboardingTitle,
                  moTa: l10n.onboardingBody,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(LbSpacing.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('bat-dau'),
                    onPressed: () =>
                        ref.read(caiDatProvider.notifier).xongGioiThieu(),
                    child: Text(l10n.onboardingStart),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
