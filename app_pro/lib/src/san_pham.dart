import 'package:app_shell/app_shell.dart';
import 'package:la_ban_pro/src/phien_ban.dart';

/// Cấu hình app "La bàn Pro" theo flavor (M2, Q56).
CauHinhSanPham cauHinhPro(Flavor flavor) =>
    CauHinhSanPham(flavor: flavor, loai: LoaiApp.pro, phienBan: phienBanApp);
