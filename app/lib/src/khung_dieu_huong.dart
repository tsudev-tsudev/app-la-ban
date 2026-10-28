import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:la_ban/src/bang_an_toan.dart';
import 'package:la_ban/src/tab_app.dart';

// Nhãn điều hướng nằm trong ô cố định: chặn phóng chữ ở mức này để không tràn
// (nội dung màn hình vẫn phóng đủ theo cài đặt hệ thống).
const _phongChuToiDa = 1.3;

/// Khung 4 tab theo 3 breakpoint: compact -> thanh dưới; medium -> rail;
/// expanded -> rail mở rộng có nhãn.
class KhungDieuHuong extends ConsumerWidget {
  const new({required this.shell, super.key});

  final StatefulNavigationShell shell;

  void _chon(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(dsTabProvider);
    final l10n = context.l10n;
    final kichCo = LbKichCo.tuRong(MediaQuery.sizeOf(context).width);
    if (kichCo == LbKichCo.compact) {
      return Scaffold(
        body: KhungAnToan(child: shell),
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: _phongChuToiDa,
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _chon,
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  key: ValueKey('tab${t.duongDan}'),
                  icon: LbIcon(t.icon),
                  label: t.nhan(l10n),
                ),
            ],
          ),
        ),
      );
    }
    final moRong = kichCo == LbKichCo.expanded;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            LayoutBuilder(
              // Rail không tự cuộn: màn ngang thấp + chữ lớn -> cuộn bọc ngoài.
              builder: (context, rang) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: rang.maxHeight),
                  child: IntrinsicHeight(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: _phongChuToiDa,
                      child: NavigationRail(
                        extended: moRong,
                        labelType: moRong
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        selectedIndex: shell.currentIndex,
                        onDestinationSelected: _chon,
                        destinations: [
                          for (final t in tabs)
                            NavigationRailDestination(
                              icon: LbIcon(
                                t.icon,
                                key: ValueKey('tab${t.duongDan}'),
                              ),
                              label: Text(t.nhan(l10n)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: KhungAnToan(child: shell)),
          ],
        ),
      ),
    );
  }
}
