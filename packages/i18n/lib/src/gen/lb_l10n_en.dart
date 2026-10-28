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

  @override
  String get safeModeTitle => 'Safe mode';

  @override
  String get safeModeCrash =>
      'The app hit repeated errors, so newer features are paused. The compass still works normally.';

  @override
  String get safeModeStorage =>
      'Your saved data could not be opened. It is kept unchanged and the compass still works.';

  @override
  String get safeModeNewer =>
      'Your data was created by a newer version. Update the app to use it again.';

  @override
  String get safeModeRetry => 'Try normal mode';

  @override
  String get safeModeRetryDone => 'Restart the app to apply.';

  @override
  String get featurePaused => 'This feature is temporarily paused.';
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

  @override
  String get safeModeTitle => '[Šảfẽ mởđẽ ····]';

  @override
  String get safeModeCrash =>
      '[Ťhẽ ảpp hỉť řẽpẽảťẽđ ẽřřởřš, šở ñẽŵẽř fẽảťữřẽš ảřẽ pảữšẽđ. Ťhẽ çởmpảšš šťỉłł ŵởřkš ñởřmảłłỹ. ·····································]';

  @override
  String get safeModeStorage =>
      '[Ỹởữř šảvẽđ đảťả çởữłđ ñởť bẽ ởpẽñẽđ. Ỉť ỉš kẽpť ữñçhảñğẽđ ảñđ ťhẽ çởmpảšš šťỉłł ŵởřkš. ···································]';

  @override
  String get safeModeNewer =>
      '[Ỹởữř đảťả ŵảš çřẽảťẽđ bỹ ả ñẽŵẽř vẽřšỉởñ. Ữpđảťẽ ťhẽ ảpp ťở ữšẽ ỉť ảğảỉñ. ······························]';

  @override
  String get safeModeRetry => '[Ťřỹ ñởřmảł mởđẽ ······]';

  @override
  String get safeModeRetryDone => '[Řẽšťảřť ťhẽ ảpp ťở ảppłỹ. ··········]';

  @override
  String get featurePaused =>
      '[Ťhỉš fẽảťữřẽ ỉš ťẽmpởřảřỉłỹ pảữšẽđ. ··············]';
}
