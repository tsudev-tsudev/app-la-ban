// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'lb_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LbL10nEn extends LbL10n {
  LbL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Compass';

  @override
  String get logoLabel => 'Compass logo';

  @override
  String get tabCompass => 'Compass';

  @override
  String get tabMap => 'Map';

  @override
  String get tabWaypoints => 'Waypoints';

  @override
  String get tabSettings => 'Settings';

  @override
  String get compassPlaceholder =>
      'The compass dial will appear here once the sensors are ready.';

  @override
  String get mapPlaceholder => 'The offline map will appear here.';

  @override
  String get waypointsEmptyTitle => 'No waypoints yet';

  @override
  String get waypointsEmptyBody =>
      'Save your current location to find your way back later.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get optionSystem => 'System default';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLicenses => 'Open-source licenses';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get onboardingTitle => 'Welcome to Compass';

  @override
  String get onboardingBody =>
      'An accurate compass that works offline and keeps your data on your device.';

  @override
  String get onboardingStart => 'Get started';
}

/// The translations for English (`en_XA`).
class LbL10nEnXa extends LbL10nEn {
  LbL10nEnXa() : super('en_XA');

  @override
  String get appTitle => '[Çởmpảšš ···]';

  @override
  String get logoLabel => '[Çởmpảšš łởğở ·····]';

  @override
  String get tabCompass => '[Çởmpảšš ···]';

  @override
  String get tabMap => '[Mảp ··]';

  @override
  String get tabWaypoints => '[Ŵảỹpởỉñťš ····]';

  @override
  String get tabSettings => '[Šẽťťỉñğš ····]';

  @override
  String get compassPlaceholder =>
      '[Ťhẽ çởmpảšš đỉảł ŵỉłł ảppẽảř hẽřẽ ởñçẽ ťhẽ šẽñšởřš ảřẽ řẽảđỹ. ·························]';

  @override
  String get mapPlaceholder =>
      '[Ťhẽ ởffłỉñẽ mảp ŵỉłł ảppẽảř hẽřẽ. ··············]';

  @override
  String get waypointsEmptyTitle => '[Ñở ŵảỹpởỉñťš ỹẽť ·······]';

  @override
  String get waypointsEmptyBody =>
      '[Šảvẽ ỹởữř çữřřẽñť łởçảťỉởñ ťở fỉñđ ỹởữř ŵảỹ bảçk łảťẽř. ······················]';

  @override
  String get settingsLanguage => '[Łảñğữảğẽ ····]';

  @override
  String get settingsTheme => '[Ảppẽảřảñçẽ ····]';

  @override
  String get optionSystem => '[Šỹšťẽm đẽfảữłť ······]';

  @override
  String get languageVietnamese => '[Ťỉếñğ Vỉệť ····]';

  @override
  String get languageEnglish => '[Ẽñğłỉšh ···]';

  @override
  String get themeLight => '[Łỉğhť ··]';

  @override
  String get themeDark => '[Đảřk ··]';

  @override
  String get settingsLicenses => '[Ởpẽñ-šởữřçẽ łỉçẽñšẽš ········]';

  @override
  String settingsVersion(String version) {
    return '[Vẽřšỉởñ $version ····]';
  }

  @override
  String get onboardingTitle => '[Ŵẽłçởmẽ ťở Çởmpảšš ········]';

  @override
  String get onboardingBody =>
      '[Ảñ ảççữřảťẽ çởmpảšš ťhảť ŵởřkš ởffłỉñẽ ảñđ kẽẽpš ỹởữř đảťả ởñ ỹởữř đẽvỉçẽ. ······························]';

  @override
  String get onboardingStart => '[Ğẽť šťảřťẽđ ·····]';
}
