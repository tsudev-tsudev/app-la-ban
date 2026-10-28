import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _duongDan = 'packages/location_feature/assets/GIAY_PHEP_DU_LIEU.txt';

/// Đăng ký ghi công dữ liệu địa giới (© OpenStreetMap contributors, ODbL) và
/// geoid EGM96 (NGA, phạm vi công cộng) vào màn "Giấy phép". Gọi một lần lúc
/// khởi động; văn bản chỉ đọc khi màn đó mở.
void dangKyGiayPhepDuLieu({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final vanBan = await (bundle ?? rootBundle).loadString(_duongDan);
    yield LicenseEntryWithLineBreaks(const [
      'OpenStreetMap (ODbL)',
      'EGM96',
    ], vanBan);
  });
}
