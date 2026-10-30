import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _sqlcipher = 'packages/storage/assets/GIAY_PHEP_SQLCIPHER.txt';
const _openssl = 'packages/storage/assets/GIAY_PHEP_OPENSSL.txt';

/// Đăng ký giấy phép thư viện native của CSDL mã hoá vào màn "Giấy phép":
/// SQLCipher (BSD, Zetetic) và OpenSSL (Apache 2.0, bản Android SQLCipher
/// liên kết). drift / sqlite3 là gói pub - Flutter tự thêm. Gọi một lần lúc
/// khởi động; văn bản chỉ đọc khi màn đó mở.
void dangKyGiayPhepLuuTru({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final b = bundle ?? rootBundle;
    yield LicenseEntryWithLineBreaks(const [
      'SQLCipher',
    ], await b.loadString(_sqlcipher));
    yield LicenseEntryWithLineBreaks(const [
      'OpenSSL',
    ], await b.loadString(_openssl));
  });
}
