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

  @override
  String get locTitle => 'Vị trí & thông số';

  @override
  String get locIntro =>
      'Bật vị trí để dùng bắc thực, toạ độ, độ cao và giờ mặt trời mọc / lặn. Vị trí chỉ dùng trên máy, không gửi đi.';

  @override
  String get locAllow => 'Cho phép vị trí';

  @override
  String get locDeniedForever =>
      'Quyền vị trí đã bị tắt. Bật lại trong Cài đặt của ứng dụng.';

  @override
  String get locOpenSettings => 'Mở cài đặt';

  @override
  String get locServiceOff => 'Dịch vụ vị trí của máy đang tắt.';

  @override
  String get locSearching => 'Đang tìm vị trí...';

  @override
  String get locApproximate => 'Đang dùng vị trí xấp xỉ';

  @override
  String get locDetails => 'Chi tiết';

  @override
  String get locCopied => 'Đã chép toạ độ';

  @override
  String get locCopy => 'Chép';

  @override
  String get locCycleFormat => 'Đổi định dạng toạ độ';

  @override
  String locAccuracy(int value) {
    return '±$value m';
  }

  @override
  String locAltitude(int value) {
    return 'Cao $value m';
  }

  @override
  String get locOutsideVn => 'Ngoài lãnh thổ Việt Nam';

  @override
  String get locOsmCredit => 'Địa giới © OpenStreetMap contributors (ODbL)';

  @override
  String get locSectionCoords => 'Toạ độ';

  @override
  String get locSectionPlace => 'Địa giới hành chính';

  @override
  String get locSectionAltitude => 'Độ cao';

  @override
  String get locSectionMotion => 'Di chuyển';

  @override
  String get locSectionField => 'Từ trường';

  @override
  String get locSectionLevel => 'Thước thuỷ';

  @override
  String get locSectionSun => 'Mặt trời';

  @override
  String get locSectionMoon => 'Mặt trăng';

  @override
  String get locFormatDd => 'Độ thập phân';

  @override
  String get locFormatDms => 'Độ phút giây';

  @override
  String get locFormatUtm => 'UTM';

  @override
  String get locFormatMgrs => 'MGRS';

  @override
  String get locNotAvailable => 'Không có';

  @override
  String get locHorizontalAccuracy => 'Sai số ngang';

  @override
  String get locAltGps => 'GPS (trên mực biển)';

  @override
  String get locAltBaro => 'Khí áp kế';

  @override
  String get locBaroCalibrated => 'đã hiệu chỉnh theo GPS';

  @override
  String get locBaroStandard => 'theo áp suất chuẩn 1013 hPa';

  @override
  String get locPressure => 'Áp suất';

  @override
  String locMeters(int value) {
    return '$value m';
  }

  @override
  String locMetersPm(int value, int acc) {
    return '$value m ±$acc m';
  }

  @override
  String locHpa(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString hPa';
  }

  @override
  String get locSpeed => 'Tốc độ';

  @override
  String locKmh(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString km/h';
  }

  @override
  String get locCourse => 'Hướng đi';

  @override
  String locDegrees(int value) {
    return '$value°';
  }

  @override
  String get locFieldMeasured => 'Đo được';

  @override
  String get locFieldModel => 'Mô hình WMM';

  @override
  String locMicroTesla(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString µT';
  }

  @override
  String locFieldDeviation(int value) {
    return 'Lệch $value%';
  }

  @override
  String get locFieldAbnormal =>
      'Từ trường bất thường (bình thường 25-65 µT): có thể có nam châm hoặc kim loại gần máy.';

  @override
  String locLevelTilt(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return 'Nghiêng $valueString°';
  }

  @override
  String get locLevelOk => 'Cân bằng';

  @override
  String get locLevelHint => 'Đặt máy nằm trên mặt cần đo.';

  @override
  String get locRise => 'Mọc';

  @override
  String get locSet => 'Lặn';

  @override
  String get locNoon => 'Trưa thực';

  @override
  String get locTransit => 'Qua kinh tuyến';

  @override
  String get locAlwaysUp => 'Ở trên chân trời cả ngày';

  @override
  String get locAlwaysDown => 'Ở dưới chân trời cả ngày';

  @override
  String get locNow => 'Hiện tại';

  @override
  String locSkyPosition(int az, int alt) {
    return 'Phương vị $az° · cao $alt°';
  }

  @override
  String locMoonIllumination(int value) {
    return 'Sáng $value%';
  }

  @override
  String get locNeedLocationSky => 'Cần vị trí để tính giờ mọc / lặn.';

  @override
  String get moonNew => 'Trăng mới';

  @override
  String get moonWaxingCrescent => 'Trăng lưỡi liềm đầu tháng';

  @override
  String get moonFirstQuarter => 'Trăng thượng huyền';

  @override
  String get moonWaxingGibbous => 'Trăng khuyết đầu tháng';

  @override
  String get moonFull => 'Trăng tròn';

  @override
  String get moonWaningGibbous => 'Trăng khuyết cuối tháng';

  @override
  String get moonLastQuarter => 'Trăng hạ huyền';

  @override
  String get moonWaningCrescent => 'Trăng lưỡi liềm cuối tháng';

  @override
  String get locSourceGps => 'GPS';

  @override
  String get locSourceNetwork => 'Mạng';

  @override
  String get locSourceFused => 'Hợp nhất';

  @override
  String get updateRequiredTitle => 'Cần cập nhật ứng dụng';

  @override
  String get updateRequiredBody =>
      'Phiên bản này không còn được hỗ trợ vì lý do bảo mật. Hãy tải bản mới để tiếp tục sử dụng.';

  @override
  String get updateAvailableTitle => 'Đã có phiên bản mới';

  @override
  String updateAvailableBody(String phienBan) {
    return 'Bản $phienBan đã sẵn sàng với các bản sửa lỗi và cải thiện.';
  }

  @override
  String get updateAvailableBodyGeneric =>
      'Bản mới đã sẵn sàng với các bản sửa lỗi và cải thiện.';

  @override
  String get updateNow => 'Cập nhật';

  @override
  String get updateLater => 'Để sau';

  @override
  String get updateOpenFailed =>
      'Không mở được trình duyệt. Hãy vào compass.tsudev.com/tai-ve để tải bản mới.';
}
