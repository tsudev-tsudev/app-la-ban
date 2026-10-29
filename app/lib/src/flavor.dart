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

  /// Tên hiển thị trên launcher.
  String get appName => switch (this) {
    Flavor.dev => 'La bàn DEV',
    Flavor.staging => 'La bàn STG',
    Flavor.prod => 'La bàn',
  };
}
