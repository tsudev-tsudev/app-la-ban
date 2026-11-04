/// Môi trường build. Mỗi flavor có applicationId / bundle id riêng để cài song song.
enum Flavor {
  /// Máy dev, API `wrangler dev`.
  dev,

  /// Bản thử nội bộ, API staging.
  staging,

  /// Bản phát hành store.
  prod;

  /// Gốc API `la-ban-api`. dev: `wrangler dev` qua máy chủ giả lập Android.
  Uri get apiGoc => Uri.parse(switch (this) {
    Flavor.dev => 'http://10.0.2.2:8797',
    Flavor.staging => 'https://compass-api-stg.tsudev.com',
    Flavor.prod => 'https://compass-api.tsudev.com',
  });

  /// Project number Google Cloud `app-la-ban` cho Play Integrity (không bí
  /// mật). Dùng được cả khi app chưa lên Play; sau khi tạo app trên Play
  /// Console chỉ cần liên kết đúng dự án này (App integrity), không đổi mã.
  static const soDuAnCloud = 930761930572;

  /// SHA-256 chứng chỉ khoá upload (QUYET_DINH Q34) - công khai, giống
  /// `PI_CHUNG_CHI` của Worker. Bản release ký khoá khác = đóng gói lại
  /// (SEC-APP APP-03, chỉ là tín hiệu gửi server).
  static const chungChiUpload =
      'cf09e7243bca9ab5d29dc788bbd31ba71efaebab7d69583d98bbfc5184a7f6bd';

  /// SHA-256 chứng chỉ khoá ký ứng dụng do Google Play tạo (Play App Signing,
  /// QUYET_DINH Q63) - bản cài từ Play mang chữ ký này, bản APK tải trực tiếp
  /// mang [chungChiUpload]. Công khai, giống `PI_CHUNG_CHI` của Worker.
  static const chungChiPlay =
      'b84d419196141b48c74609824b3ff41ebcc3f51f86c94b561fbbd20440f18b7b';

  /// Mọi chứng chỉ ký hợp lệ của bản release (APK trực tiếp + Play).
  static const List<String> chungChiHopLe = [chungChiUpload, chungChiPlay];

  /// applicationId (android/app/build.gradle.kts: hậu tố theo flavor).
  String get goi => switch (this) {
    Flavor.dev => 'com.tsudev.laban.dev',
    Flavor.staging => 'com.tsudev.laban.stg',
    Flavor.prod => 'com.tsudev.laban',
  };

  /// Tên hiển thị trên launcher.
  String get appName => switch (this) {
    Flavor.dev => 'La bàn DEV',
    Flavor.staging => 'La bàn STG',
    Flavor.prod => 'La bàn',
  };
}
