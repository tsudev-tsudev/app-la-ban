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

  /// Nội dung tạm của tab La bàn
  ///
  /// In vi, this message translates to:
  /// **'Mặt la bàn sẽ hiện ở đây sau khi cảm biến sẵn sàng.'**
  String get compassPlaceholder;

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
