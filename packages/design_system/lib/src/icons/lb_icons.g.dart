// TỆP SINH - đừng sửa tay. Nguồn: design/icons/*.svg · lệnh: node tools/build/icon-dart.mjs

import 'dart:ui';

import 'package:design_system/src/icons/lb_icon_data.dart';

/// Bộ icon 24dp (khung 24 x 24, vẽ nét). Dùng với `LbIcon`.
abstract final class LbIcons {
  /// `design/icons/bac-thuc.svg`
  static const bacThuc = LbIconData('bac-thuc', _bacThuc);

  /// `design/icons/ban-do.svg`
  static const banDo = LbIconData('ban-do', _banDo);

  /// `design/icons/cai-dat.svg`
  static const caiDat = LbIconData('cai-dat', _caiDat);

  /// `design/icons/camera-ar.svg`
  static const cameraAr = LbIconData('camera-ar', _cameraAr);

  /// `design/icons/chia-se-qr.svg`
  static const chiaSeQr = LbIconData('chia-se-qr', _chiaSeQr);

  /// `design/icons/diem-moc.svg`
  static const diemMoc = LbIconData('diem-moc', _diemMoc);

  /// `design/icons/ghim-gps.svg`
  static const ghimGps = LbIconData('ghim-gps', _ghimGps);

  /// `design/icons/hieu-chuan-so-8.svg`
  static const hieuChuanSo8 = LbIconData('hieu-chuan-so-8', _hieuChuanSo8);

  /// `design/icons/khien.svg`
  static const khien = LbIconData('khien', _khien);

  /// `design/icons/la-ban-hoa-gio.svg`
  static const laBanHoaGio = LbIconData('la-ban-hoa-gio', _laBanHoaGio);

  /// `design/icons/mat-la-ban-3d.svg`
  static const matLaBan3d = LbIconData('mat-la-ban-3d', _matLaBan3d);

  /// `design/icons/thuoc-thuy.svg`
  static const thuocThuy = LbIconData('thuoc-thuy', _thuocThuy);

  /// Mọi icon, theo tên tệp.
  static const all = <LbIconData>[
    bacThuc,
    banDo,
    caiDat,
    cameraAr,
    chiaSeQr,
    diemMoc,
    ghimGps,
    hieuChuanSo8,
    khien,
    laBanHoaGio,
    matLaBan3d,
    thuocThuy,
  ];
}

void _bacThuc(Path p) {
  p.moveTo(12, 3);
  p.lineTo(18, 20);
  p.lineTo(12, 16);
  p.lineTo(6, 20);
  p.close();
  p.moveTo(12, 3);
  p.lineTo(12, 16);
}

void _banDo(Path p) {
  p.moveTo(3, 6);
  p.lineTo(9, 4);
  p.lineTo(15, 6);
  p.lineTo(21, 4);
  p.lineTo(21, 18);
  p.lineTo(15, 20);
  p.lineTo(9, 18);
  p.lineTo(3, 20);
  p.close();
  p.moveTo(9, 4);
  p.lineTo(9, 18);
  p.moveTo(15, 6);
  p.lineTo(15, 20);
}

void _caiDat(Path p) {
  p.moveTo(4, 6);
  p.lineTo(13, 6);
  p.moveTo(17, 6);
  p.lineTo(20, 6);
  p.moveTo(4, 12);
  p.lineTo(7, 12);
  p.moveTo(11, 12);
  p.lineTo(20, 12);
  p.moveTo(4, 18);
  p.lineTo(15, 18);
  p.moveTo(19, 18);
  p.lineTo(20, 18);
  p.addOval(Rect.fromCircle(center: const Offset(15, 6), radius: 2));
  p.addOval(Rect.fromCircle(center: const Offset(9, 12), radius: 2));
  p.addOval(Rect.fromCircle(center: const Offset(17, 18), radius: 2));
}

void _cameraAr(Path p) {
  p.moveTo(3, 7);
  p.lineTo(3, 4);
  p.lineTo(6, 4);
  p.moveTo(18, 4);
  p.lineTo(21, 4);
  p.lineTo(21, 7);
  p.moveTo(21, 17);
  p.lineTo(21, 20);
  p.lineTo(18, 20);
  p.moveTo(6, 20);
  p.lineTo(3, 20);
  p.lineTo(3, 17);
  p.moveTo(12, 7);
  p.lineTo(17, 9.8);
  p.lineTo(17, 15.2);
  p.lineTo(12, 18);
  p.lineTo(7, 15.2);
  p.lineTo(7, 9.8);
  p.close();
  p.moveTo(7, 9.8);
  p.lineTo(12, 12.6);
  p.lineTo(17, 9.8);
  p.moveTo(12, 12.6);
  p.lineTo(12, 18);
}

void _chiaSeQr(Path p) {
  p.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 3, 7, 7),
      const Radius.elliptical(1, 1),
    ),
  );
  p.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(14, 3, 7, 7),
      const Radius.elliptical(1, 1),
    ),
  );
  p.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 14, 7, 7),
      const Radius.elliptical(1, 1),
    ),
  );
  p.moveTo(14, 14);
  p.lineTo(17, 14);
  p.lineTo(17, 17);
  p.lineTo(14, 17);
  p.close();
  p.moveTo(21, 14);
  p.lineTo(21, 14.01);
  p.moveTo(21, 21);
  p.lineTo(17, 21);
  p.moveTo(21, 17.5);
  p.lineTo(21, 21);
  p.moveTo(14, 21);
  p.lineTo(14, 20.99);
}

void _diemMoc(Path p) {
  p.moveTo(6, 21);
  p.lineTo(6, 4);
  p.moveTo(6, 4);
  p.lineTo(18, 4);
  p.lineTo(15, 8);
  p.lineTo(18, 12);
  p.lineTo(6, 12);
}

void _ghimGps(Path p) {
  p.moveTo(12, 21);
  p.cubicTo(12, 21, 5, 14.8, 5, 9.5);
  p.arcToPoint(
    const Offset(19, 9.5),
    radius: const Radius.elliptical(7, 7),
    rotation: 0,
    largeArc: false,
    clockwise: true,
  );
  p.cubicTo(19, 14.8, 12, 21, 12, 21);
  p.close();
  p.addOval(Rect.fromCircle(center: const Offset(12, 9.5), radius: 2.5));
}

void _hieuChuanSo8(Path p) {
  p.moveTo(12, 12);
  p.cubicTo(10, 9.3, 8.4, 8, 6.5, 8);
  p.arcToPoint(
    const Offset(6.5, 16),
    radius: const Radius.elliptical(4, 4),
    rotation: 0,
    largeArc: false,
    clockwise: false,
  );
  p.cubicTo(8.4, 16, 10, 14.7, 12, 12);
  p.cubicTo(14, 9.3, 15.6, 8, 17.5, 8);
  p.arcToPoint(
    const Offset(17.5, 16),
    radius: const Radius.elliptical(4, 4),
    rotation: 0,
    largeArc: false,
    clockwise: true,
  );
  p.cubicTo(15.6, 16, 14, 14.7, 12, 12);
  p.close();
  p.moveTo(15.8, 6.4);
  p.lineTo(17.6, 8);
  p.lineTo(16, 9.7);
}

void _khien(Path p) {
  p.moveTo(12, 3);
  p.lineTo(19, 6);
  p.lineTo(19, 11);
  p.cubicTo(19, 15.5, 16, 19.3, 12, 21);
  p.cubicTo(8, 19.3, 5, 15.5, 5, 11);
  p.lineTo(5, 6);
  p.close();
  p.moveTo(9, 12);
  p.lineTo(11, 14);
  p.lineTo(15, 10);
}

void _laBanHoaGio(Path p) {
  p.moveTo(12, 2);
  p.lineTo(14.2, 9.8);
  p.lineTo(22, 12);
  p.lineTo(14.2, 14.2);
  p.lineTo(12, 22);
  p.lineTo(9.8, 14.2);
  p.lineTo(2, 12);
  p.lineTo(9.8, 9.8);
  p.close();
  p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 1));
}

void _matLaBan3d(Path p) {
  p.addOval(
    Rect.fromCenter(center: const Offset(12, 11), width: 18, height: 10),
  );
  p.moveTo(3, 11);
  p.lineTo(3, 13.5);
  p.cubicTo(3, 16.3, 7, 18.5, 12, 18.5);
  p.cubicTo(17, 18.5, 21, 16.3, 21, 13.5);
  p.lineTo(21, 11);
  p.moveTo(8.5, 13);
  p.lineTo(15.5, 9);
  p.addOval(Rect.fromCircle(center: const Offset(12, 11), radius: 0.5));
}

void _thuocThuy(Path p) {
  p.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 8, 20, 8),
      const Radius.elliptical(3, 3),
    ),
  );
  p.moveTo(8.5, 8);
  p.lineTo(8.5, 16);
  p.moveTo(15.5, 8);
  p.lineTo(15.5, 16);
  p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 1.5));
}
