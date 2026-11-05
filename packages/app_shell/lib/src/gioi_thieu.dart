import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:settings_feature/settings_feature.dart';

/// Màn giới thiệu lần đầu: logo động (cùng biểu tượng với splash native ->
/// chuyển mượt), một câu giới thiệu, thông báo xử lý dữ liệu (NĐ 13/2023) và
/// hai lựa chọn: đồng ý gửi dữ liệu bảo mật kỹ thuật, hoặc chỉ dùng ngoại
/// tuyến. Hiện lại (không còn bước chào) khi thông báo có bản mới.
class ManGioiThieu extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chu = Theme.of(context).textTheme;
    final tb = ref.read(caiDatProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, rang) => SingleChildScrollView(
                  padding: const EdgeInsets.all(LbSpacing.lg),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          LbLogoDong(
                            // Màn thấp / chữ lớn: logo nhỏ lại, nhường
                            // chỗ cho thông báo dữ liệu.
                            size: [
                              120.0,
                              rang.biggest.shortestSide * 0.3,
                              rang.maxHeight * 0.18,
                            ].reduce(math.min),
                            semanticLabel: l10n.logoLabel,
                          ),
                          const SizedBox(height: LbSpacing.md),
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.onboardingTitle,
                              style: chu.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: LbSpacing.xs),
                          Text(
                            l10n.onboardingBody,
                            style: chu.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: LbSpacing.lg),
                          const ThongBaoDuLieu(),
                          const SizedBox(height: LbSpacing.xs),
                          Text(l10n.consentOfflineHint, style: chu.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LbSpacing.md,
                LbSpacing.xs,
                LbSpacing.md,
                LbSpacing.md,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      key: const ValueKey('bat-dau'),
                      onPressed: () => tb.datDongY(trucTuyen: true),
                      child: Text(l10n.consentAccept),
                    ),
                    const SizedBox(height: LbSpacing.xs),
                    OutlinedButton(
                      key: const ValueKey('ngoai-tuyen'),
                      onPressed: () => tb.datDongY(trucTuyen: false),
                      child: Text(l10n.consentOffline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
