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
  String get compassPlaceholder =>
      'Mặt la bàn sẽ hiện ở đây sau khi cảm biến sẵn sàng.';

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
}
