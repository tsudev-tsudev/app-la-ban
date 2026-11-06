import 'package:app_shell/src/ar.dart';
import 'package:app_shell/src/bang_an_toan.dart';
import 'package:app_shell/src/chuyen_pro.dart';
import 'package:app_shell/src/luu_tru.dart';
import 'package:app_shell/src/phien_ban.dart';
import 'package:app_shell/src/pro.dart';
import 'package:compass_feature/compass_feature.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:location_feature/location_feature.dart';
import 'package:map_feature/map_feature.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:storage/storage.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// Một tab của khung điều hướng chính.
typedef TabApp = ({
  String duongDan,
  LbIconData icon,
  String Function(LbL10n l10n) nhan,
  Widget man,
});

/// 4 tab: La bàn · Bản đồ · Điểm · Cài đặt. Test override để thay màn hình.
/// Tab vẫn hiện khi cờ tắt (giữ bố cục quen) nhưng thay màn bằng [ManTamTat].
final dsTabProvider = Provider<List<TabApp>>((ref) {
  final co = ref.watch(coTinhNangProvider);
  return [
    (
      duongDan: '/la-ban',
      icon: LbIcons.laBanHoaGio,
      nhan: (l) => l.tabCompass,
      man: const ManLaBan(theDuoi: TheViTri(), hanhDong: [NutAr()]),
    ),
    (
      duongDan: '/ban-do',
      icon: LbIcons.banDo,
      nhan: (l) => l.tabMap,
      man: co[CoTinhNang.banDo]! ? const ManBanDo() : const ManTamTat(),
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
      man: ManCaiDat(
        phienBan: phienBanApp,
        mucPro: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [MucProApp(), MucChuyenPro()],
        ),
      ),
    ),
  ];
});
