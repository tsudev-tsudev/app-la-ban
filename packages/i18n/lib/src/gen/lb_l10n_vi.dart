// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'lb_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class LbL10nVi extends LbL10n {
  LbL10nVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'La bàn';

  @override
  String get logoLabel => 'Logo La bàn';

  @override
  String get tabCompass => 'La bàn';

  @override
  String get tabMap => 'Bản đồ';

  @override
  String get tabWaypoints => 'Điểm';

  @override
  String get tabSettings => 'Cài đặt';

  @override
  String get mapPlaceholder => 'Bản đồ ngoại tuyến sẽ hiện ở đây.';

  @override
  String get waypointsEmptyTitle => 'Chưa có điểm nào';

  @override
  String get waypointsEmptyBody =>
      'Lưu vị trí hiện tại để tìm đường quay lại sau.';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsTheme => 'Giao diện';

  @override
  String get optionSystem => 'Theo hệ thống';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get settingsLicenses => 'Giấy phép mã nguồn mở';

  @override
  String settingsVersion(String version) {
    return 'Phiên bản $version';
  }

  @override
  String get onboardingTitle => 'Chào mừng đến với La bàn';

  @override
  String get onboardingBody =>
      'La bàn chính xác, dùng được khi không có mạng và giữ dữ liệu của bạn trên máy.';

  @override
  String get onboardingStart => 'Bắt đầu';

  @override
  String get safeModeTitle => 'Chế độ an toàn';

  @override
  String get safeModeCrash =>
      'Ứng dụng gặp lỗi nhiều lần nên đã tạm tắt các tính năng mới. La bàn vẫn hoạt động bình thường.';

  @override
  String get safeModeStorage =>
      'Chưa mở được dữ liệu đã lưu. Dữ liệu cũ vẫn được giữ nguyên, la bàn vẫn hoạt động.';

  @override
  String get safeModeNewer =>
      'Dữ liệu được tạo bởi phiên bản mới hơn. Hãy cập nhật ứng dụng để dùng lại.';

  @override
  String get safeModeRetry => 'Thử chế độ thường';

  @override
  String get safeModeRetryDone => 'Mở lại ứng dụng để áp dụng.';

  @override
  String get featurePaused => 'Tính năng này đang tạm tắt.';

  @override
  String get compassStarting => 'Đang khởi động cảm biến...';

  @override
  String get compassNoSensor =>
      'Thiết bị này không có cảm biến la bàn (từ kế).';

  @override
  String get compassError => 'Không đọc được cảm biến. Hãy mở lại ứng dụng.';

  @override
  String compassDegrees(int value) {
    return '$value°';
  }

  @override
  String get compassMagneticNorth => 'Theo bắc từ';

  @override
  String compassHeadingSemantics(int value, String direction) {
    return 'Hướng $value độ, $direction';
  }

  @override
  String compassTilt(int pitch, int roll) {
    return 'Ngóc $pitch° · Nghiêng $roll°';
  }

  @override
  String compassAccuracy(String level) {
    return 'Độ tin cậy: $level';
  }

  @override
  String get accuracyHigh => 'Cao';

  @override
  String get accuracyMedium => 'Trung bình';

  @override
  String get accuracyLow => 'Thấp';

  @override
  String get compassInterference =>
      'Nhiễu từ: tránh xa nam châm, loa, ốp lưng có nam châm hoặc vật kim loại lớn.';

  @override
  String get compassCalibrate =>
      'Độ chính xác thấp: cầm máy vẽ hình số 8 trong không khí vài lần.';

  @override
  String get dirShortN => 'B';

  @override
  String get dirLongN => 'Bắc';

  @override
  String get dirShortNE => 'ĐB';

  @override
  String get dirLongNE => 'Đông Bắc';

  @override
  String get dirShortE => 'Đ';

  @override
  String get dirLongE => 'Đông';

  @override
  String get dirShortSE => 'ĐN';

  @override
  String get dirLongSE => 'Đông Nam';

  @override
  String get dirShortS => 'N';

  @override
  String get dirLongS => 'Nam';

  @override
  String get dirShortSW => 'TN';

  @override
  String get dirLongSW => 'Tây Nam';

  @override
  String get dirShortW => 'T';

  @override
  String get dirLongW => 'Tây';

  @override
  String get dirShortNW => 'TB';

  @override
  String get dirLongNW => 'Tây Bắc';

  @override
  String compassHeadingPrecise(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString°';
  }

  @override
  String get compassTrueNorth => 'Theo bắc thực';

  @override
  String compassDeclination(double value, String side) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return 'Độ lệch từ $valueString° $side';
  }

  @override
  String get compassNeedLocation =>
      'Chưa có vị trí nên đang theo bắc từ. Bắc thực cần vị trí để tính độ lệch từ.';

  @override
  String get compassModelExpired =>
      'Mô hình từ trường đã hết hạn, độ lệch có thể kém chính xác. Hãy cập nhật ứng dụng.';

  @override
  String compassFieldStrength(int value) {
    return 'Từ trường $value µT';
  }

  @override
  String get compassCameraMode => 'Theo hướng camera sau';

  @override
  String get compassOptions => 'Tuỳ chọn la bàn';

  @override
  String get compassOptionTrueNorth => 'Bắc thực';

  @override
  String get compassOptionTrueNorthHint =>
      'Cộng độ lệch từ theo mô hình WMM2025, tính ngoại tuyến.';

  @override
  String get compassOptionHaptic => 'Rung khi qua hướng chính';

  @override
  String get compassOptionHapticHint =>
      'Rung nhẹ mỗi khi kim đi qua một trong 8 hướng.';

  @override
  String get compassCalibrateAction => 'Hiệu chuẩn';

  @override
  String get calibTitle => 'Hiệu chuẩn la bàn';

  @override
  String get calibInstruction =>
      'Cầm chắc máy, xoay cổ tay vẽ hình số 8 trong không khí. Lần lượt nghiêng máy lên, xuống, sang trái, sang phải.';

  @override
  String get calibTip =>
      'Đứng xa nam châm, loa, sạc không dây, ốp lưng có nam châm và vật kim loại lớn.';

  @override
  String calibProgress(int percent) {
    return 'Đã quét $percent%';
  }

  @override
  String calibDone(String level) {
    return 'Hiệu chuẩn xong. Độ tin cậy: $level.';
  }

  @override
  String get calibFinish => 'Xong';
}
