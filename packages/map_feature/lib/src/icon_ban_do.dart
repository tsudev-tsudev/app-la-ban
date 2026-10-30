import 'dart:ui';

import 'package:design_system/design_system.dart';

// Icon nét 24dp riêng của tab Bản đồ, cùng kiểu nét với LbIcons (như IconDiem
// của tab Điểm). Phát sinh: chuyển về
// design/icons/*.svg khi phase sau đụng design/.
abstract final class IconBanDo {
  static const taiVe = LbIconData('tai-ve', _taiVe);
  static const xoa = LbIconData('xoa', _xoa);
}

void _taiVe(Path p) => p
  ..moveTo(12, 3)
  ..lineTo(12, 15)
  ..moveTo(7, 10)
  ..lineTo(12, 15)
  ..lineTo(17, 10)
  ..moveTo(4, 17)
  ..lineTo(4, 20)
  ..lineTo(20, 20)
  ..lineTo(20, 17);

void _xoa(Path p) => p
  ..moveTo(4, 7)
  ..lineTo(20, 7)
  ..moveTo(9, 7)
  ..lineTo(9, 4)
  ..lineTo(15, 4)
  ..lineTo(15, 7)
  ..moveTo(6, 7)
  ..lineTo(7, 20)
  ..lineTo(17, 20)
  ..lineTo(18, 7)
  ..moveTo(10, 11)
  ..lineTo(10, 16)
  ..moveTo(14, 11)
  ..lineTo(14, 16);
