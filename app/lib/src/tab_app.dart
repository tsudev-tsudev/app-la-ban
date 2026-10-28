import 'package:compass_feature/compass_feature.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:la_ban/src/phien_ban.dart';
import 'package:map_feature/map_feature.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// Một tab của khung điều hướng chính.
typedef TabApp = ({
  String duongDan,
  LbIconData icon,
  String Function(LbL10n l10n) nhan,
  Widget man,
});

/// 4 tab: La bàn · Bản đồ · Điểm · Cài đặt. Test override để thay màn hình.
final dsTabProvider = Provider<List<TabApp>>(
  (ref) => [
    (
      duongDan: '/la-ban',
      icon: LbIcons.laBanHoaGio,
      nhan: (l) => l.tabCompass,
      man: const ManLaBan(),
    ),
    (
      duongDan: '/ban-do',
      icon: LbIcons.banDo,
      nhan: (l) => l.tabMap,
      man: const ManBanDo(),
    ),
    (
      duongDan: '/diem',
      icon: LbIcons.diemMoc,
      nhan: (l) => l.tabWaypoints,
      man: const ManDiem(),
    ),
    (
      duongDan: '/cai-dat',
      icon: LbIcons.caiDat,
      nhan: (l) => l.tabSettings,
      man: const ManCaiDat(phienBan: phienBanApp),
    ),
  ],
);
