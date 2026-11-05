import 'package:app_shell/app_shell.dart';
import 'package:la_ban/src/phien_ban.dart';

/// Cấu hình bản miễn phí theo flavor (M2: vỏ app ở packages/app_shell).
CauHinhSanPham cauHinhMienPhi(Flavor flavor) => CauHinhSanPham(
  flavor: flavor,
  loai: LoaiApp.mienPhi,
  phienBan: phienBanApp,
);
