/// Môi trường build. Mỗi flavor có applicationId / bundle id riêng để cài song song.
enum Flavor {
  /// Máy dev, API `wrangler dev`.
  dev,

  /// Bản thử nội bộ, API staging.
  staging,

  /// Bản phát hành store.
  prod;

  /// Tên hiển thị trên launcher.
  String get appName => switch (this) {
    Flavor.dev => 'La bàn DEV',
    Flavor.staging => 'La bàn STG',
    Flavor.prod => 'La bàn',
  };
}
