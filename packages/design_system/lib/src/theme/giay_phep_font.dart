import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _duongDanOfl = 'packages/design_system/fonts/OFL.txt';

/// Đăng ký giấy phép SIL OFL 1.1 của font Be Vietnam Pro để hiện ở màn
/// "Giấy phép" (`showLicensePage`). Gọi một lần lúc khởi động; văn bản chỉ
/// đọc khi màn đó mở.
void dangKyGiayPhepFont({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final vanBan = await (bundle ?? rootBundle).loadString(_duongDanOfl);
    yield LicenseEntryWithLineBreaks(const ['Be Vietnam Pro'], vanBan);
  });
}
