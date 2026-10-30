import 'dart:ui';

import 'package:design_system/design_system.dart';

// Icon nét 24dp riêng của tab Điểm, cùng kiểu nét với LbIcons. Phát sinh:
// chuyển về design/icons/*.svg (nguồn duy nhất) khi phase sau đụng design/.
abstract final class IconDiem {
  static const them = LbIconData('them', _them);
  static const xoa = LbIconData('xoa', _xoa);
  static const sua = LbIconData('sua', _sua);
  static const tuyChon = LbIconData('tuy-chon', _tuyChon);
  static const muiTen = LbIconData('mui-ten', _muiTen);
  static const anh = LbIconData('anh', _anh);
  static const saoChep = LbIconData('sao-chep', _saoChep);
  static const tep = LbIconData('tep', _tep);
}

void _them(Path p) => p
  ..moveTo(12, 5)
  ..lineTo(12, 19)
  ..moveTo(5, 12)
  ..lineTo(19, 12);

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

void _sua(Path p) => p
  ..moveTo(4, 20)
  ..lineTo(4.5, 16)
  ..lineTo(15.5, 5)
  ..lineTo(19, 8.5)
  ..lineTo(8, 19.5)
  ..close()
  ..moveTo(13, 7.5)
  ..lineTo(16.5, 11);

void _tuyChon(Path p) => p
  ..addOval(const Rect.fromLTWH(11, 4.5, 2, 2))
  ..addOval(const Rect.fromLTWH(11, 11, 2, 2))
  ..addOval(const Rect.fromLTWH(11, 17.5, 2, 2));

void _muiTen(Path p) => p
  ..moveTo(12, 3)
  ..lineTo(19, 20)
  ..lineTo(12, 16)
  ..lineTo(5, 20)
  ..close();

void _anh(Path p) => p
  ..addRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(3, 5, 18, 14),
      const Radius.circular(2),
    ),
  )
  ..addOval(const Rect.fromLTWH(7, 8, 3, 3))
  ..moveTo(3, 17)
  ..lineTo(9, 12.5)
  ..lineTo(13, 15.5)
  ..lineTo(16, 13)
  ..lineTo(21, 17);

void _saoChep(Path p) => p
  ..addRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, 8, 12, 12),
      const Radius.circular(2),
    ),
  )
  ..moveTo(16, 8)
  ..lineTo(16, 5)
  ..arcToPoint(
    const Offset(14, 4),
    radius: const Radius.circular(1.5),
    clockwise: false,
  )
  ..lineTo(6, 4)
  ..arcToPoint(
    const Offset(4, 6),
    radius: const Radius.circular(1.5),
    clockwise: false,
  )
  ..lineTo(4, 14)
  ..arcToPoint(
    const Offset(6, 16),
    radius: const Radius.circular(1.5),
    clockwise: false,
  )
  ..lineTo(8, 16);

void _tep(Path p) => p
  ..moveTo(6, 3)
  ..lineTo(14, 3)
  ..lineTo(19, 8)
  ..lineTo(19, 21)
  ..lineTo(6, 21)
  ..close()
  ..moveTo(14, 3)
  ..lineTo(14, 8)
  ..lineTo(19, 8);
