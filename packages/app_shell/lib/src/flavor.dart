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
}

/// Sản phẩm trên Play (M2, QUYET_DINH Q56): cùng mã nguồn, hai listing.
enum LoaiApp {
  /// `app/` - La bàn miễn phí (gói Pro mua trong app, M1).
  mienPhi,

  /// `app_pro/` - La bàn Pro trả phí một lần, không SDK quảng cáo; quyền lợi
  /// `pro_app` do Worker cấp khi Play Integrity báo `LICENSED`.
  pro,
}

/// Cấu hình của một bản build: môi trường x sản phẩm x phiên bản. `main` của
/// `app/` và `app_pro/` truyền vào `khoiDong`.
final class CauHinhSanPham {
  const new({required this.flavor, required this.loai, required this.phienBan});

  /// Môi trường (API, chứng chỉ ký).
  final Flavor flavor;

  /// Bản miễn phí hay bản Pro.
  final LoaiApp loai;

  /// `version:` trong pubspec.yaml của app đó (test của từng app kiểm khớp).
  final String phienBan;

  /// Đây là app "La bàn Pro".
  bool get laPro => loai == LoaiApp.pro;

  /// applicationId (build.gradle.kts: gốc theo sản phẩm + hậu tố flavor).
  String get goi {
    final goc = laPro ? 'com.tsudev.laban.pro' : 'com.tsudev.laban';
    return switch (flavor) {
      Flavor.dev => '$goc.dev',
      Flavor.staging => '$goc.stg',
      Flavor.prod => goc,
    };
  }

  /// Tên launcher của flavor dev / staging (prod lấy chuỗi ARB theo ngôn
  /// ngữ - `appTitle` / `appTitlePro`).
  String get appName {
    final goc = laPro ? 'La bàn Pro' : 'La bàn';
    return switch (flavor) {
      Flavor.dev => '$goc DEV',
      Flavor.staging => '$goc STG',
      Flavor.prod => goc,
    };
  }
}
