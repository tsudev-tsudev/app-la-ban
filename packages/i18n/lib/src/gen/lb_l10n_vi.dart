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

  @override
  String securityRef(String ref) {
    return 'Mã tham chiếu: $ref';
  }

  @override
  String get securityCopyRef => 'Chép mã';

  @override
  String get securityRefCopied => 'Đã chép mã tham chiếu';

  @override
  String get securityRestrictedTitle => 'Một số tính năng đang bị hạn chế';

  @override
  String get securityRestrictedBody =>
      'Thiết bị này tạm thời không dùng được các tính năng trực tuyến. La bàn vẫn hoạt động bình thường.';

  @override
  String get securityLockedTitle => 'Ứng dụng tạm khoá trên thiết bị này';

  @override
  String get securityLockedBody =>
      'Vì lý do an toàn, ứng dụng không thể tiếp tục trên thiết bị này. Nếu bạn cho rằng đây là nhầm lẫn, hãy gửi khiếu nại kèm mã tham chiếu bên dưới.';

  @override
  String get securityAppeal => 'Gửi khiếu nại';

  @override
  String get securityAppealOpenFailed =>
      'Không mở được trình duyệt. Hãy vào compass.tsudev.com/khieu-nai để gửi khiếu nại.';

  @override
  String get wpSaveHere => 'Lưu vị trí';

  @override
  String get wpAddManual => 'Nhập toạ độ';

  @override
  String get wpNewTitle => 'Điểm mới';

  @override
  String get wpEditTitle => 'Sửa điểm';

  @override
  String get wpName => 'Tên';

  @override
  String get wpLat => 'Vĩ độ';

  @override
  String get wpLon => 'Kinh độ';

  @override
  String get wpAlt => 'Cao độ (m, tuỳ chọn)';

  @override
  String get wpNote => 'Ghi chú';

  @override
  String get wpPhotos => 'Ảnh';

  @override
  String get wpAddPhoto => 'Thêm ảnh';

  @override
  String get wpRemovePhoto => 'Xoá ảnh';

  @override
  String wpPhotoSemantics(int index) {
    return 'Ảnh $index của điểm';
  }

  @override
  String get wpPhotoHint =>
      'Ảnh được thu nhỏ và xoá thông tin vị trí / máy chụp trước khi lưu.';

  @override
  String get wpPhotoError => 'Không đọc được ảnh này.';

  @override
  String get wpSave => 'Lưu';

  @override
  String get wpCancel => 'Huỷ';

  @override
  String get wpDelete => 'Xoá';

  @override
  String wpDeleteConfirm(String name) {
    return 'Xoá \"$name\" cùng ảnh của điểm? Không hoàn tác được.';
  }

  @override
  String get wpUseCurrent => 'Dùng vị trí hiện tại';

  @override
  String get wpLocating => 'Đang lấy vị trí...';

  @override
  String get wpLocationNeeded => 'Cần quyền vị trí để lưu chỗ bạn đang đứng.';

  @override
  String get wpGrant => 'Cho phép vị trí';

  @override
  String get wpErrNameEmpty => 'Nhập tên điểm';

  @override
  String wpErrNameLong(int max) {
    return 'Tên tối đa $max ký tự';
  }

  @override
  String get wpErrLat => 'Vĩ độ từ -90 đến 90';

  @override
  String get wpErrLon => 'Kinh độ từ -180 đến 180';

  @override
  String get wpErrAlt => 'Cao độ không hợp lệ';

  @override
  String wpErrNoteLong(int max) {
    return 'Ghi chú tối đa $max ký tự';
  }

  @override
  String get wpNavigate => 'Dẫn đường';

  @override
  String get wpShare => 'Chia sẻ';

  @override
  String get wpEdit => 'Sửa';

  @override
  String wpMeters(int value) {
    return '$value m';
  }

  @override
  String wpKilometers(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString km';
  }

  @override
  String wpAway(String distance) {
    return 'Cách $distance';
  }

  @override
  String wpBearing(int value) {
    return 'Hướng $value° (bắc thực)';
  }

  @override
  String wpTurn(int value, String side) {
    return 'Quay $value° sang $side';
  }

  @override
  String get wpLeft => 'trái';

  @override
  String get wpRight => 'phải';

  @override
  String get wpAhead => 'Đi thẳng';

  @override
  String get wpArrived => 'Đã tới nơi';

  @override
  String get wpNoCompass =>
      'Máy không có cảm biến la bàn: đi theo hướng bên dưới bằng la bàn khác.';

  @override
  String get wpWaitingGps => 'Đang chờ vị trí GPS...';

  @override
  String wpAccuracy(int value) {
    return 'Sai số vị trí ±$value m';
  }

  @override
  String wpArrowSemantics(String name, String distance) {
    return 'Mũi tên chỉ tới $name, $distance';
  }

  @override
  String wpCreated(String date) {
    return 'Tạo lúc $date';
  }

  @override
  String get wpCoords => 'Toạ độ';

  @override
  String wpAltValue(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return 'Cao độ $valueString m';
  }

  @override
  String get wpCopyCoords => 'Sao chép toạ độ';

  @override
  String get wpImport => 'Nhập GPX / KML';

  @override
  String get wpExportGpx => 'Xuất GPX';

  @override
  String get wpExportKml => 'Xuất KML';

  @override
  String get wpMore => 'Thêm tuỳ chọn';

  @override
  String wpImportResult(int added, int updated, int skipped) {
    return 'Đã thêm $added, cập nhật $updated, bỏ qua $skipped điểm.';
  }

  @override
  String get wpImportError =>
      'Không đọc được tệp: không phải GPX / KML hợp lệ.';

  @override
  String get wpImportEmpty => 'Tệp không có điểm nào.';

  @override
  String get wpFileError => 'Không mở / lưu được tệp.';

  @override
  String get wpExported => 'Đã lưu tệp.';

  @override
  String wpUnnamed(int index) {
    return 'Điểm $index';
  }

  @override
  String get wpShareTitle => 'Chia sẻ điểm';

  @override
  String get wpShareExpiry => 'Link hết hạn sau';

  @override
  String wpDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ngày',
      one: '1 ngày',
    );
    return '$_temp0';
  }

  @override
  String wpShareInfo(int max) {
    return 'Link chứa tên, toạ độ, cao độ và tối đa $max ký tự ghi chú, không kèm ảnh. Ai có link đều xem được tới khi hết hạn.';
  }

  @override
  String get wpCopyLink => 'Sao chép link';

  @override
  String get wpCopied => 'Đã sao chép';

  @override
  String get wpSendLink => 'Gửi link';

  @override
  String get wpQrSemantics => 'Mã QR của link chia sẻ';

  @override
  String get wpShareDisabled => 'Chia sẻ đang tạm tắt.';

  @override
  String get wpReceivedTitle => 'Điểm được chia sẻ';

  @override
  String wpReceivedExpires(String date) {
    return 'Link hết hạn lúc $date';
  }

  @override
  String get wpReceivedSave => 'Lưu vào Điểm';

  @override
  String get wpReceivedSaved => 'Đã lưu vào Điểm.';

  @override
  String get wpReceivedUntrusted =>
      'Nội dung do người gửi đặt, ứng dụng không kiểm chứng.';

  @override
  String get wpLinkBroken => 'Link không hợp lệ hoặc bị cắt mất khi gửi.';

  @override
  String get wpLinkExpired => 'Link đã hết hạn. Hãy nhờ người gửi chia sẻ lại.';

  @override
  String get wpLinkNewer =>
      'Link được tạo bởi phiên bản mới hơn. Hãy cập nhật ứng dụng.';

  @override
  String get wpGoWaypoints => 'Mở danh sách điểm';

  @override
  String get wpSafeTitle => 'Xuất điểm đã lưu';

  @override
  String get wpSafeBody =>
      'Ở chế độ an toàn, danh sách điểm tạm khoá. Bạn vẫn có thể xuất toàn bộ điểm ra tệp GPX để giữ an toàn.';

  @override
  String get wpSafeReadError => 'Không đọc được điểm đã lưu.';

  @override
  String wpSafeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count điểm',
      zero: 'Không có điểm nào',
    );
    return '$_temp0';
  }

  @override
  String get mapMyLocation => 'Vị trí của tôi';

  @override
  String get mapNoLocation => 'Chưa có vị trí - đang chờ GPS.';

  @override
  String get mapFollowHeading => 'Xoay bản đồ theo hướng';

  @override
  String get mapNorthUp => 'Đưa hướng bắc lên trên';

  @override
  String get mapOffline => 'Bản đồ ngoại tuyến';

  @override
  String get mapOfflineIntro =>
      'Tải trước vùng bản đồ để dùng khi không có mạng: chế độ máy bay, vùng núi, trên biển.';

  @override
  String get mapOfflineOverview => 'Tổng quan Việt Nam';

  @override
  String get mapOfflineOverviewDesc =>
      'Cả nước, gồm quần đảo Hoàng Sa và Trường Sa; đường chính, tên tỉnh và thành phố.';

  @override
  String get mapOfflineCurrent => 'Vùng đang xem';

  @override
  String mapOfflineCurrentDesc(int tiles) {
    return '$tiles ô bản đồ, chi tiết tới từng con phố.';
  }

  @override
  String mapOfflineTooLarge(int tiles) {
    return 'Vùng quá rộng ($tiles ô). Hãy phóng to bản đồ rồi tải lại.';
  }

  @override
  String get mapOfflineNoView => 'Mở tab Bản đồ và di chuyển tới vùng cần tải.';

  @override
  String get mapOfflineDownload => 'Tải về';

  @override
  String mapOfflineDownloading(int done, int total) {
    return 'Đang tải $done/$total';
  }

  @override
  String get mapOfflineDone => 'Đã tải xong vùng bản đồ.';

  @override
  String get mapOfflineFailed =>
      'Chưa tải xong - kiểm tra kết nối mạng rồi thử lại.';

  @override
  String get mapOfflineSaved => 'Vùng đã tải';

  @override
  String get mapOfflineEmpty => 'Chưa có vùng nào.';

  @override
  String get mapOfflineDelete => 'Xoá vùng';

  @override
  String mapOfflineDeleteTitle(String name) {
    return 'Xoá vùng \"$name\"?';
  }

  @override
  String mapOfflineStorage(double mb) {
    final intl.NumberFormat mbNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String mbString = mbNumberFormat.format(mb);

    return 'Đang dùng $mbString MB trên máy';
  }

  @override
  String mapOfflineAreaName(String date) {
    return 'Vùng $date';
  }

  @override
  String mapOfflineZoom(int from, int to) {
    return 'Mức chi tiết $from-$to';
  }
}
