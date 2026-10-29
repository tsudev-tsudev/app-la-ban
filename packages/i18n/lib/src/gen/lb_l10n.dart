import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'lb_l10n_en.dart';
import 'lb_l10n_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of LbL10n
/// returned by `LbL10n.of(context)`.
///
/// Applications need to include `LbL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/lb_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: LbL10n.localizationsDelegates,
///   supportedLocales: LbL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the LbL10n.supportedLocales
/// property.
abstract class LbL10n {
  LbL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static LbL10n of(BuildContext context) {
    return Localizations.of<LbL10n>(context, LbL10n)!;
  }

  static const LocalizationsDelegate<LbL10n> delegate = _LbL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'XA'),
    Locale('vi'),
  ];

  /// Tên ứng dụng hiển thị trong app
  ///
  /// In vi, this message translates to:
  /// **'La bàn'**
  String get appTitle;

  /// Nhãn trợ năng của logo
  ///
  /// In vi, this message translates to:
  /// **'Logo La bàn'**
  String get logoLabel;

  /// Tab điều hướng: mặt la bàn
  ///
  /// In vi, this message translates to:
  /// **'La bàn'**
  String get tabCompass;

  /// Tab điều hướng: bản đồ
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ'**
  String get tabMap;

  /// Tab điều hướng: điểm mốc đã lưu
  ///
  /// In vi, this message translates to:
  /// **'Điểm'**
  String get tabWaypoints;

  /// Tab điều hướng: cài đặt
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get tabSettings;

  /// Nội dung tạm của tab Bản đồ
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ ngoại tuyến sẽ hiện ở đây.'**
  String get mapPlaceholder;

  /// Tiêu đề khi danh sách điểm mốc trống
  ///
  /// In vi, this message translates to:
  /// **'Chưa có điểm nào'**
  String get waypointsEmptyTitle;

  /// Mô tả khi danh sách điểm mốc trống
  ///
  /// In vi, this message translates to:
  /// **'Lưu vị trí hiện tại để tìm đường quay lại sau.'**
  String get waypointsEmptyBody;

  /// Mục cài đặt ngôn ngữ
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get settingsLanguage;

  /// Mục cài đặt sáng / tối
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get settingsTheme;

  /// Lựa chọn theo cài đặt của hệ điều hành
  ///
  /// In vi, this message translates to:
  /// **'Theo hệ thống'**
  String get optionSystem;

  /// Tên tiếng Việt - luôn viết bằng chính ngôn ngữ đó
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVietnamese;

  /// Tên tiếng Anh - luôn viết bằng chính ngôn ngữ đó
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Giao diện sáng
  ///
  /// In vi, this message translates to:
  /// **'Sáng'**
  String get themeLight;

  /// Giao diện tối
  ///
  /// In vi, this message translates to:
  /// **'Tối'**
  String get themeDark;

  /// Mở danh sách giấy phép phần mềm / font
  ///
  /// In vi, this message translates to:
  /// **'Giấy phép mã nguồn mở'**
  String get settingsLicenses;

  /// Dòng phiên bản ứng dụng
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản {version}'**
  String settingsVersion(String version);

  /// Tiêu đề màn giới thiệu lần đầu
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng đến với La bàn'**
  String get onboardingTitle;

  /// Mô tả màn giới thiệu lần đầu
  ///
  /// In vi, this message translates to:
  /// **'La bàn chính xác, dùng được khi không có mạng và giữ dữ liệu của bạn trên máy.'**
  String get onboardingBody;

  /// Nút đóng màn giới thiệu
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get onboardingStart;

  /// Tiêu đề băng báo chế độ an toàn
  ///
  /// In vi, this message translates to:
  /// **'Chế độ an toàn'**
  String get safeModeTitle;

  /// Lý do: crash liên tiếp
  ///
  /// In vi, this message translates to:
  /// **'Ứng dụng gặp lỗi nhiều lần nên đã tạm tắt các tính năng mới. La bàn vẫn hoạt động bình thường.'**
  String get safeModeCrash;

  /// Lý do: lỗi CSDL / migration
  ///
  /// In vi, this message translates to:
  /// **'Chưa mở được dữ liệu đã lưu. Dữ liệu cũ vẫn được giữ nguyên, la bàn vẫn hoạt động.'**
  String get safeModeStorage;

  /// Lý do: CSDL của bản app mới hơn
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu được tạo bởi phiên bản mới hơn. Hãy cập nhật ứng dụng để dùng lại.'**
  String get safeModeNewer;

  /// Nút thoát chế độ an toàn
  ///
  /// In vi, this message translates to:
  /// **'Thử chế độ thường'**
  String get safeModeRetry;

  /// Thông báo sau khi bấm thoát chế độ an toàn
  ///
  /// In vi, this message translates to:
  /// **'Mở lại ứng dụng để áp dụng.'**
  String get safeModeRetryDone;

  /// Màn hình thay thế khi cờ tính năng tắt
  ///
  /// In vi, this message translates to:
  /// **'Tính năng này đang tạm tắt.'**
  String get featurePaused;

  /// Trạng thái chờ luồng cảm biến đầu tiên
  ///
  /// In vi, this message translates to:
  /// **'Đang khởi động cảm biến...'**
  String get compassStarting;

  /// Máy không có cảm biến từ trường
  ///
  /// In vi, this message translates to:
  /// **'Thiết bị này không có cảm biến la bàn (từ kế).'**
  String get compassNoSensor;

  /// Lỗi luồng cảm biến khác
  ///
  /// In vi, this message translates to:
  /// **'Không đọc được cảm biến. Hãy mở lại ứng dụng.'**
  String get compassError;

  /// Số độ của hướng (đã làm tròn)
  ///
  /// In vi, this message translates to:
  /// **'{value}°'**
  String compassDegrees(int value);

  /// Chú thích: hướng đang tính theo bắc từ
  ///
  /// In vi, this message translates to:
  /// **'Theo bắc từ'**
  String get compassMagneticNorth;

  /// Nhãn trình đọc màn hình cho hướng
  ///
  /// In vi, this message translates to:
  /// **'Hướng {value} độ, {direction}'**
  String compassHeadingSemantics(int value, String direction);

  /// Góc ngóc / nghiêng của máy
  ///
  /// In vi, this message translates to:
  /// **'Ngóc {pitch}° · Nghiêng {roll}°'**
  String compassTilt(int pitch, int roll);

  /// Mức tin cậy hướng
  ///
  /// In vi, this message translates to:
  /// **'Độ tin cậy: {level}'**
  String compassAccuracy(String level);

  /// Mức tin cậy cao
  ///
  /// In vi, this message translates to:
  /// **'Cao'**
  String get accuracyHigh;

  /// Mức tin cậy trung bình
  ///
  /// In vi, this message translates to:
  /// **'Trung bình'**
  String get accuracyMedium;

  /// Mức tin cậy thấp
  ///
  /// In vi, this message translates to:
  /// **'Thấp'**
  String get accuracyLow;

  /// Cảnh báo nhiễu từ
  ///
  /// In vi, this message translates to:
  /// **'Nhiễu từ: tránh xa nam châm, loa, ốp lưng có nam châm hoặc vật kim loại lớn.'**
  String get compassInterference;

  /// Hướng dẫn hiệu chuẩn hình số 8
  ///
  /// In vi, this message translates to:
  /// **'Độ chính xác thấp: cầm máy vẽ hình số 8 trong không khí vài lần.'**
  String get compassCalibrate;

  /// Ký hiệu hướng Bắc
  ///
  /// In vi, this message translates to:
  /// **'B'**
  String get dirShortN;

  /// Tên đầy đủ hướng Bắc
  ///
  /// In vi, this message translates to:
  /// **'Bắc'**
  String get dirLongN;

  /// Ký hiệu hướng Đông Bắc
  ///
  /// In vi, this message translates to:
  /// **'ĐB'**
  String get dirShortNE;

  /// Tên đầy đủ hướng Đông Bắc
  ///
  /// In vi, this message translates to:
  /// **'Đông Bắc'**
  String get dirLongNE;

  /// Ký hiệu hướng Đông
  ///
  /// In vi, this message translates to:
  /// **'Đ'**
  String get dirShortE;

  /// Tên đầy đủ hướng Đông
  ///
  /// In vi, this message translates to:
  /// **'Đông'**
  String get dirLongE;

  /// Ký hiệu hướng Đông Nam
  ///
  /// In vi, this message translates to:
  /// **'ĐN'**
  String get dirShortSE;

  /// Tên đầy đủ hướng Đông Nam
  ///
  /// In vi, this message translates to:
  /// **'Đông Nam'**
  String get dirLongSE;

  /// Ký hiệu hướng Nam
  ///
  /// In vi, this message translates to:
  /// **'N'**
  String get dirShortS;

  /// Tên đầy đủ hướng Nam
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get dirLongS;

  /// Ký hiệu hướng Tây Nam
  ///
  /// In vi, this message translates to:
  /// **'TN'**
  String get dirShortSW;

  /// Tên đầy đủ hướng Tây Nam
  ///
  /// In vi, this message translates to:
  /// **'Tây Nam'**
  String get dirLongSW;

  /// Ký hiệu hướng Tây
  ///
  /// In vi, this message translates to:
  /// **'T'**
  String get dirShortW;

  /// Tên đầy đủ hướng Tây
  ///
  /// In vi, this message translates to:
  /// **'Tây'**
  String get dirLongW;

  /// Ký hiệu hướng Tây Bắc
  ///
  /// In vi, this message translates to:
  /// **'TB'**
  String get dirShortNW;

  /// Tên đầy đủ hướng Tây Bắc
  ///
  /// In vi, this message translates to:
  /// **'Tây Bắc'**
  String get dirLongNW;

  /// Số độ của hướng, 1 chữ số thập phân
  ///
  /// In vi, this message translates to:
  /// **'{value}°'**
  String compassHeadingPrecise(double value);

  /// Chú thích: hướng đang tính theo bắc thực (địa lý)
  ///
  /// In vi, this message translates to:
  /// **'Theo bắc thực'**
  String get compassTrueNorth;

  /// Độ lệch từ WMM tại vị trí hiện tại; side = Đông / Tây
  ///
  /// In vi, this message translates to:
  /// **'Độ lệch từ {value}° {side}'**
  String compassDeclination(double value, String side);

  /// Người dùng chọn bắc thực nhưng app chưa có vị trí
  ///
  /// In vi, this message translates to:
  /// **'Chưa có vị trí nên đang theo bắc từ. Bắc thực cần vị trí để tính độ lệch từ.'**
  String get compassNeedLocation;

  /// WMM quá hạn hiệu lực
  ///
  /// In vi, this message translates to:
  /// **'Mô hình từ trường đã hết hạn, độ lệch có thể kém chính xác. Hãy cập nhật ứng dụng.'**
  String get compassModelExpired;

  /// Cường độ từ trường đo được
  ///
  /// In vi, this message translates to:
  /// **'Từ trường {value} µT'**
  String compassFieldStrength(int value);

  /// Máy dựng đứng: hướng tính theo camera sau
  ///
  /// In vi, this message translates to:
  /// **'Theo hướng camera sau'**
  String get compassCameraMode;

  /// Nút / tiêu đề bảng tuỳ chọn la bàn
  ///
  /// In vi, this message translates to:
  /// **'Tuỳ chọn la bàn'**
  String get compassOptions;

  /// Công tắc: dùng bắc thực
  ///
  /// In vi, this message translates to:
  /// **'Bắc thực'**
  String get compassOptionTrueNorth;

  /// Mô tả công tắc bắc thực
  ///
  /// In vi, this message translates to:
  /// **'Cộng độ lệch từ theo mô hình WMM2025, tính ngoại tuyến.'**
  String get compassOptionTrueNorthHint;

  /// Công tắc: rung nhẹ khi qua 8 hướng
  ///
  /// In vi, this message translates to:
  /// **'Rung khi qua hướng chính'**
  String get compassOptionHaptic;

  /// Mô tả công tắc rung
  ///
  /// In vi, this message translates to:
  /// **'Rung nhẹ mỗi khi kim đi qua một trong 8 hướng.'**
  String get compassOptionHapticHint;

  /// Nút mở màn hiệu chuẩn
  ///
  /// In vi, this message translates to:
  /// **'Hiệu chuẩn'**
  String get compassCalibrateAction;

  /// Tiêu đề màn hiệu chuẩn
  ///
  /// In vi, this message translates to:
  /// **'Hiệu chuẩn la bàn'**
  String get calibTitle;

  /// Hướng dẫn hiệu chuẩn hình số 8
  ///
  /// In vi, this message translates to:
  /// **'Cầm chắc máy, xoay cổ tay vẽ hình số 8 trong không khí. Lần lượt nghiêng máy lên, xuống, sang trái, sang phải.'**
  String get calibInstruction;

  /// Mẹo khi hiệu chuẩn
  ///
  /// In vi, this message translates to:
  /// **'Đứng xa nam châm, loa, sạc không dây, ốp lưng có nam châm và vật kim loại lớn.'**
  String get calibTip;

  /// Tiến độ hiệu chuẩn
  ///
  /// In vi, this message translates to:
  /// **'Đã quét {percent}%'**
  String calibProgress(int percent);

  /// Kết quả hiệu chuẩn
  ///
  /// In vi, this message translates to:
  /// **'Hiệu chuẩn xong. Độ tin cậy: {level}.'**
  String calibDone(String level);

  /// Nút đóng màn hiệu chuẩn
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get calibFinish;

  /// Tiêu đề màn vị trí / telemetry
  ///
  /// In vi, this message translates to:
  /// **'Vị trí & thông số'**
  String get locTitle;

  /// Lời mời bật vị trí (trước khi hỏi quyền)
  ///
  /// In vi, this message translates to:
  /// **'Bật vị trí để dùng bắc thực, toạ độ, độ cao và giờ mặt trời mọc / lặn. Vị trí chỉ dùng trên máy, không gửi đi.'**
  String get locIntro;

  /// Nút xin quyền vị trí
  ///
  /// In vi, this message translates to:
  /// **'Cho phép vị trí'**
  String get locAllow;

  /// Quyền bị từ chối hẳn
  ///
  /// In vi, this message translates to:
  /// **'Quyền vị trí đã bị tắt. Bật lại trong Cài đặt của ứng dụng.'**
  String get locDeniedForever;

  /// Nút mở cài đặt app / vị trí
  ///
  /// In vi, this message translates to:
  /// **'Mở cài đặt'**
  String get locOpenSettings;

  /// Dịch vụ vị trí tắt
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ vị trí của máy đang tắt.'**
  String get locServiceOff;

  /// Chờ lần đọc vị trí đầu
  ///
  /// In vi, this message translates to:
  /// **'Đang tìm vị trí...'**
  String get locSearching;

  /// Chỉ có quyền vị trí xấp xỉ
  ///
  /// In vi, this message translates to:
  /// **'Đang dùng vị trí xấp xỉ'**
  String get locApproximate;

  /// Nút mở màn chi tiết vị trí
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết'**
  String get locDetails;

  /// Thông báo đã chép
  ///
  /// In vi, this message translates to:
  /// **'Đã chép toạ độ'**
  String get locCopied;

  /// Nút chép toạ độ
  ///
  /// In vi, this message translates to:
  /// **'Chép'**
  String get locCopy;

  /// Gợi ý chạm để đổi định dạng
  ///
  /// In vi, this message translates to:
  /// **'Đổi định dạng toạ độ'**
  String get locCycleFormat;

  /// Sai số ngang (m)
  ///
  /// In vi, this message translates to:
  /// **'±{value} m'**
  String locAccuracy(int value);

  /// Độ cao ngắn gọn trên thẻ
  ///
  /// In vi, this message translates to:
  /// **'Cao {value} m'**
  String locAltitude(int value);

  /// Không tra được địa giới VN
  ///
  /// In vi, this message translates to:
  /// **'Ngoài lãnh thổ Việt Nam'**
  String get locOutsideVn;

  /// Ghi công dữ liệu OSM
  ///
  /// In vi, this message translates to:
  /// **'Địa giới © OpenStreetMap contributors (ODbL)'**
  String get locOsmCredit;

  /// Mục toạ độ
  ///
  /// In vi, this message translates to:
  /// **'Toạ độ'**
  String get locSectionCoords;

  /// Mục địa giới
  ///
  /// In vi, this message translates to:
  /// **'Địa giới hành chính'**
  String get locSectionPlace;

  /// Mục độ cao
  ///
  /// In vi, this message translates to:
  /// **'Độ cao'**
  String get locSectionAltitude;

  /// Mục tốc độ / hướng đi
  ///
  /// In vi, this message translates to:
  /// **'Di chuyển'**
  String get locSectionMotion;

  /// Mục từ trường
  ///
  /// In vi, this message translates to:
  /// **'Từ trường'**
  String get locSectionField;

  /// Mục thước thuỷ
  ///
  /// In vi, this message translates to:
  /// **'Thước thuỷ'**
  String get locSectionLevel;

  /// Mục mặt trời
  ///
  /// In vi, this message translates to:
  /// **'Mặt trời'**
  String get locSectionSun;

  /// Mục mặt trăng
  ///
  /// In vi, this message translates to:
  /// **'Mặt trăng'**
  String get locSectionMoon;

  /// Tên định dạng DD
  ///
  /// In vi, this message translates to:
  /// **'Độ thập phân'**
  String get locFormatDd;

  /// Tên định dạng DMS
  ///
  /// In vi, this message translates to:
  /// **'Độ phút giây'**
  String get locFormatDms;

  /// Tên định dạng UTM
  ///
  /// In vi, this message translates to:
  /// **'UTM'**
  String get locFormatUtm;

  /// Tên định dạng MGRS
  ///
  /// In vi, this message translates to:
  /// **'MGRS'**
  String get locFormatMgrs;

  /// Giá trị không có
  ///
  /// In vi, this message translates to:
  /// **'Không có'**
  String get locNotAvailable;

  /// Nhãn sai số ngang
  ///
  /// In vi, this message translates to:
  /// **'Sai số ngang'**
  String get locHorizontalAccuracy;

  /// Nhãn độ cao GPS
  ///
  /// In vi, this message translates to:
  /// **'GPS (trên mực biển)'**
  String get locAltGps;

  /// Nhãn độ cao khí áp
  ///
  /// In vi, this message translates to:
  /// **'Khí áp kế'**
  String get locAltBaro;

  /// Ghi chú khí áp đã hiệu chỉnh
  ///
  /// In vi, this message translates to:
  /// **'đã hiệu chỉnh theo GPS'**
  String get locBaroCalibrated;

  /// Ghi chú khí áp chưa hiệu chỉnh
  ///
  /// In vi, this message translates to:
  /// **'theo áp suất chuẩn 1013 hPa'**
  String get locBaroStandard;

  /// Nhãn áp suất
  ///
  /// In vi, this message translates to:
  /// **'Áp suất'**
  String get locPressure;

  /// Giá trị mét
  ///
  /// In vi, this message translates to:
  /// **'{value} m'**
  String locMeters(int value);

  /// Mét kèm sai số
  ///
  /// In vi, this message translates to:
  /// **'{value} m ±{acc} m'**
  String locMetersPm(int value, int acc);

  /// Áp suất hPa
  ///
  /// In vi, this message translates to:
  /// **'{value} hPa'**
  String locHpa(double value);

  /// Nhãn tốc độ
  ///
  /// In vi, this message translates to:
  /// **'Tốc độ'**
  String get locSpeed;

  /// Tốc độ km/h
  ///
  /// In vi, this message translates to:
  /// **'{value} km/h'**
  String locKmh(double value);

  /// Nhãn hướng di chuyển
  ///
  /// In vi, this message translates to:
  /// **'Hướng đi'**
  String get locCourse;

  /// Góc nguyên
  ///
  /// In vi, this message translates to:
  /// **'{value}°'**
  String locDegrees(int value);

  /// Nhãn từ trường đo
  ///
  /// In vi, this message translates to:
  /// **'Đo được'**
  String get locFieldMeasured;

  /// Nhãn từ trường mô hình
  ///
  /// In vi, this message translates to:
  /// **'Mô hình WMM'**
  String get locFieldModel;

  /// Giá trị µT
  ///
  /// In vi, this message translates to:
  /// **'{value} µT'**
  String locMicroTesla(double value);

  /// Lệch so với mô hình
  ///
  /// In vi, this message translates to:
  /// **'Lệch {value}%'**
  String locFieldDeviation(int value);

  /// Cảnh báo µT ngoài dải
  ///
  /// In vi, this message translates to:
  /// **'Từ trường bất thường (bình thường 25-65 µT): có thể có nam châm hoặc kim loại gần máy.'**
  String get locFieldAbnormal;

  /// Góc nghiêng thước thuỷ
  ///
  /// In vi, this message translates to:
  /// **'Nghiêng {value}°'**
  String locLevelTilt(double value);

  /// Thước thuỷ đã cân bằng
  ///
  /// In vi, this message translates to:
  /// **'Cân bằng'**
  String get locLevelOk;

  /// Gợi ý dùng thước thuỷ
  ///
  /// In vi, this message translates to:
  /// **'Đặt máy nằm trên mặt cần đo.'**
  String get locLevelHint;

  /// Giờ mọc
  ///
  /// In vi, this message translates to:
  /// **'Mọc'**
  String get locRise;

  /// Giờ lặn
  ///
  /// In vi, this message translates to:
  /// **'Lặn'**
  String get locSet;

  /// Giờ trưa thực
  ///
  /// In vi, this message translates to:
  /// **'Trưa thực'**
  String get locNoon;

  /// Giờ mặt trăng qua kinh tuyến
  ///
  /// In vi, this message translates to:
  /// **'Qua kinh tuyến'**
  String get locTransit;

  /// Không lặn trong ngày
  ///
  /// In vi, this message translates to:
  /// **'Ở trên chân trời cả ngày'**
  String get locAlwaysUp;

  /// Không mọc trong ngày
  ///
  /// In vi, this message translates to:
  /// **'Ở dưới chân trời cả ngày'**
  String get locAlwaysDown;

  /// Vị trí bầu trời hiện tại
  ///
  /// In vi, this message translates to:
  /// **'Hiện tại'**
  String get locNow;

  /// Phương vị / độ cao thiên thể
  ///
  /// In vi, this message translates to:
  /// **'Phương vị {az}° · cao {alt}°'**
  String locSkyPosition(int az, int alt);

  /// Phần trăm đĩa trăng được chiếu sáng
  ///
  /// In vi, this message translates to:
  /// **'Sáng {value}%'**
  String locMoonIllumination(int value);

  /// Chưa có vị trí cho mặt trời / mặt trăng
  ///
  /// In vi, this message translates to:
  /// **'Cần vị trí để tính giờ mọc / lặn.'**
  String get locNeedLocationSky;

  /// Pha trăng
  ///
  /// In vi, this message translates to:
  /// **'Trăng mới'**
  String get moonNew;

  /// Pha trăng
  ///
  /// In vi, this message translates to:
  /// **'Trăng lưỡi liềm đầu tháng'**
  String get moonWaxingCrescent;

  /// Pha trăng
  ///
  /// In vi, this message translates to:
  /// **'Trăng thượng huyền'**
  String get moonFirstQuarter;

  /// Pha trăng
  ///
  /// In vi, this message translates to:
  /// **'Trăng khuyết đầu tháng'**
  String get moonWaxingGibbous;

  /// Pha trăng
  ///
  /// In vi, this message translates to:
  /// **'Trăng tròn'**
  String get moonFull;

  /// Pha trăng
  ///
  /// In vi, this message translates to:
  /// **'Trăng khuyết cuối tháng'**
  String get moonWaningGibbous;

  /// Pha trăng
  ///
  /// In vi, this message translates to:
  /// **'Trăng hạ huyền'**
  String get moonLastQuarter;

  /// Pha trăng
  ///
  /// In vi, this message translates to:
  /// **'Trăng lưỡi liềm cuối tháng'**
  String get moonWaningCrescent;

  /// Nguồn vị trí
  ///
  /// In vi, this message translates to:
  /// **'GPS'**
  String get locSourceGps;

  /// Nguồn vị trí
  ///
  /// In vi, this message translates to:
  /// **'Mạng'**
  String get locSourceNetwork;

  /// Nguồn vị trí
  ///
  /// In vi, this message translates to:
  /// **'Hợp nhất'**
  String get locSourceFused;

  /// Tiêu đề màn chặn khi phiên bản quá cũ (force update)
  ///
  /// In vi, this message translates to:
  /// **'Cần cập nhật ứng dụng'**
  String get updateRequiredTitle;

  /// Nội dung màn bắt buộc cập nhật
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản này không còn được hỗ trợ vì lý do bảo mật. Hãy tải bản mới để tiếp tục sử dụng.'**
  String get updateRequiredBody;

  /// Tiêu đề băng gợi ý cập nhật
  ///
  /// In vi, this message translates to:
  /// **'Đã có phiên bản mới'**
  String get updateAvailableTitle;

  /// Băng gợi ý cập nhật
  ///
  /// In vi, this message translates to:
  /// **'Bản {phienBan} đã sẵn sàng với các bản sửa lỗi và cải thiện.'**
  String updateAvailableBody(String phienBan);

  /// Băng gợi ý cập nhật khi không biết số phiên bản
  ///
  /// In vi, this message translates to:
  /// **'Bản mới đã sẵn sàng với các bản sửa lỗi và cải thiện.'**
  String get updateAvailableBodyGeneric;

  /// Nút mở trang tải bản mới
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật'**
  String get updateNow;

  /// Nút ẩn băng gợi ý cập nhật trong phiên này
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get updateLater;

  /// Lỗi khi không mở được trang tải
  ///
  /// In vi, this message translates to:
  /// **'Không mở được trình duyệt. Hãy vào compass.tsudev.com/tai-ve để tải bản mới.'**
  String get updateOpenFailed;
}

class _LbL10nDelegate extends LocalizationsDelegate<LbL10n> {
  const _LbL10nDelegate();

  @override
  Future<LbL10n> load(Locale locale) {
    return SynchronousFuture<LbL10n>(lookupLbL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_LbL10nDelegate old) => false;
}

LbL10n lookupLbL10n(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'XA':
            return LbL10nEnXa();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LbL10nEn();
    case 'vi':
      return LbL10nVi();
  }

  throw FlutterError(
    'LbL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
