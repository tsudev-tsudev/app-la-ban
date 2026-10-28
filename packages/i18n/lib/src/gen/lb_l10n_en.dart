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

  @override
  String get compassStarting => 'Starting sensors...';

  @override
  String get compassNoSensor =>
      'This device has no compass sensor (magnetometer).';

  @override
  String get compassError =>
      'Could not read the sensors. Please reopen the app.';

  @override
  String compassDegrees(int value) {
    return '$value°';
  }

  @override
  String get compassMagneticNorth => 'Magnetic north';

  @override
  String compassHeadingSemantics(int value, String direction) {
    return 'Heading $value degrees, $direction';
  }

  @override
  String compassTilt(int pitch, int roll) {
    return 'Pitch $pitch° · Roll $roll°';
  }

  @override
  String compassAccuracy(String level) {
    return 'Accuracy: $level';
  }

  @override
  String get accuracyHigh => 'High';

  @override
  String get accuracyMedium => 'Medium';

  @override
  String get accuracyLow => 'Low';

  @override
  String get compassInterference =>
      'Magnetic interference: move away from magnets, speakers, magnetic cases or large metal objects.';

  @override
  String get compassCalibrate =>
      'Low accuracy: move your phone in a figure-8 a few times.';

  @override
  String get dirShortN => 'N';

  @override
  String get dirLongN => 'North';

  @override
  String get dirShortNE => 'NE';

  @override
  String get dirLongNE => 'Northeast';

  @override
  String get dirShortE => 'E';

  @override
  String get dirLongE => 'East';

  @override
  String get dirShortSE => 'SE';

  @override
  String get dirLongSE => 'Southeast';

  @override
  String get dirShortS => 'S';

  @override
  String get dirLongS => 'South';

  @override
  String get dirShortSW => 'SW';

  @override
  String get dirLongSW => 'Southwest';

  @override
  String get dirShortW => 'W';

  @override
  String get dirLongW => 'West';

  @override
  String get dirShortNW => 'NW';

  @override
  String get dirLongNW => 'Northwest';

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
  String get compassTrueNorth => 'True north';

  @override
  String compassDeclination(double value, String side) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return 'Declination $valueString° $side';
  }

  @override
  String get compassNeedLocation =>
      'No location yet, so showing magnetic north. True north needs your location to compute declination.';

  @override
  String get compassModelExpired =>
      'The magnetic model has expired, so declination may be less accurate. Please update the app.';

  @override
  String compassFieldStrength(int value) {
    return 'Field $value µT';
  }

  @override
  String get compassCameraMode => 'Following rear camera';

  @override
  String get compassOptions => 'Compass options';

  @override
  String get compassOptionTrueNorth => 'True north';

  @override
  String get compassOptionTrueNorthHint =>
      'Adds magnetic declination from the WMM2025 model, computed offline.';

  @override
  String get compassOptionHaptic => 'Vibrate at cardinal points';

  @override
  String get compassOptionHapticHint =>
      'A light tap each time the dial passes one of the 8 directions.';

  @override
  String get compassCalibrateAction => 'Calibrate';

  @override
  String get calibTitle => 'Calibrate compass';

  @override
  String get calibInstruction =>
      'Hold the phone firmly and move your wrist in a figure 8 in the air. Then tilt the phone up, down, left and right.';

  @override
  String get calibTip =>
      'Stay away from magnets, speakers, wireless chargers, magnetic cases and large metal objects.';

  @override
  String calibProgress(int percent) {
    return 'Scanned $percent%';
  }

  @override
  String calibDone(String level) {
    return 'Calibration done. Accuracy: $level.';
  }

  @override
  String get calibFinish => 'Done';

  @override
  String get locTitle => 'Location & telemetry';

  @override
  String get locIntro =>
      'Turn on location for true north, coordinates, altitude and sunrise / sunset times. Your location stays on this device.';

  @override
  String get locAllow => 'Allow location';

  @override
  String get locDeniedForever =>
      'Location permission is off. Turn it on in the app settings.';

  @override
  String get locOpenSettings => 'Open settings';

  @override
  String get locServiceOff => 'Device location is turned off.';

  @override
  String get locSearching => 'Finding your location...';

  @override
  String get locApproximate => 'Using approximate location';

  @override
  String get locDetails => 'Details';

  @override
  String get locCopied => 'Coordinates copied';

  @override
  String get locCopy => 'Copy';

  @override
  String get locCycleFormat => 'Change coordinate format';

  @override
  String locAccuracy(int value) {
    return '±$value m';
  }

  @override
  String locAltitude(int value) {
    return 'Alt. $value m';
  }

  @override
  String get locOutsideVn => 'Outside Vietnam';

  @override
  String get locOsmCredit => 'Boundaries © OpenStreetMap contributors (ODbL)';

  @override
  String get locSectionCoords => 'Coordinates';

  @override
  String get locSectionPlace => 'Administrative area';

  @override
  String get locSectionAltitude => 'Altitude';

  @override
  String get locSectionMotion => 'Motion';

  @override
  String get locSectionField => 'Magnetic field';

  @override
  String get locSectionLevel => 'Bubble level';

  @override
  String get locSectionSun => 'Sun';

  @override
  String get locSectionMoon => 'Moon';

  @override
  String get locFormatDd => 'Decimal degrees';

  @override
  String get locFormatDms => 'Degrees minutes seconds';

  @override
  String get locFormatUtm => 'UTM';

  @override
  String get locFormatMgrs => 'MGRS';

  @override
  String get locNotAvailable => 'Not available';

  @override
  String get locHorizontalAccuracy => 'Horizontal accuracy';

  @override
  String get locAltGps => 'GPS (above sea level)';

  @override
  String get locAltBaro => 'Barometer';

  @override
  String get locBaroCalibrated => 'calibrated with GPS';

  @override
  String get locBaroStandard => 'using standard 1013 hPa';

  @override
  String get locPressure => 'Pressure';

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
  String get locSpeed => 'Speed';

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
  String get locCourse => 'Course';

  @override
  String locDegrees(int value) {
    return '$value°';
  }

  @override
  String get locFieldMeasured => 'Measured';

  @override
  String get locFieldModel => 'WMM model';

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
    return 'Off by $value%';
  }

  @override
  String get locFieldAbnormal =>
      'Unusual magnetic field (normal is 25-65 µT): there may be a magnet or metal near the device.';

  @override
  String locLevelTilt(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return 'Tilt $valueString°';
  }

  @override
  String get locLevelOk => 'Level';

  @override
  String get locLevelHint => 'Lay the device on the surface to check.';

  @override
  String get locRise => 'Rise';

  @override
  String get locSet => 'Set';

  @override
  String get locNoon => 'Solar noon';

  @override
  String get locTransit => 'Transit';

  @override
  String get locAlwaysUp => 'Up all day';

  @override
  String get locAlwaysDown => 'Down all day';

  @override
  String get locNow => 'Now';

  @override
  String locSkyPosition(int az, int alt) {
    return 'Azimuth $az° · elevation $alt°';
  }

  @override
  String locMoonIllumination(int value) {
    return '$value% lit';
  }

  @override
  String get locNeedLocationSky => 'Location is needed for rise / set times.';

  @override
  String get moonNew => 'New moon';

  @override
  String get moonWaxingCrescent => 'Waxing crescent';

  @override
  String get moonFirstQuarter => 'First quarter';

  @override
  String get moonWaxingGibbous => 'Waxing gibbous';

  @override
  String get moonFull => 'Full moon';

  @override
  String get moonWaningGibbous => 'Waning gibbous';

  @override
  String get moonLastQuarter => 'Last quarter';

  @override
  String get moonWaningCrescent => 'Waning crescent';

  @override
  String get locSourceGps => 'GPS';

  @override
  String get locSourceNetwork => 'Network';

  @override
  String get locSourceFused => 'Fused';
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

  @override
  String get compassStarting => '[Šťảřťỉñğ šẽñšởřš... ········]';

  @override
  String get compassNoSensor =>
      '[Ťhỉš đẽvỉçẽ hảš ñở çởmpảšš šẽñšởř (mảğñẽťởmẽťẽř). ····················]';

  @override
  String get compassError =>
      '[Çởữłđ ñởť řẽảđ ťhẽ šẽñšởřš. Płẽảšẽ řẽởpẽñ ťhẽ ảpp. ····················]';

  @override
  String compassDegrees(int value) {
    return '[$value° ··]';
  }

  @override
  String get compassMagneticNorth => '[Mảğñẽťỉç ñởřťh ······]';

  @override
  String compassHeadingSemantics(int value, String direction) {
    return '[Hẽảđỉñğ $value đẽğřẽẽš, $direction ········]';
  }

  @override
  String compassTilt(int pitch, int roll) {
    return '[Pỉťçh $pitch° · Řởłł $roll° ·······]';
  }

  @override
  String compassAccuracy(String level) {
    return '[Ảççữřảçỹ: $level ····]';
  }

  @override
  String get accuracyHigh => '[Hỉğh ··]';

  @override
  String get accuracyMedium => '[Mẽđỉữm ···]';

  @override
  String get accuracyLow => '[Łởŵ ··]';

  @override
  String get compassInterference =>
      '[Mảğñẽťỉç ỉñťẽřfẽřẽñçẽ: mởvẽ ảŵảỹ fřởm mảğñẽťš, špẽảkẽřš, mảğñẽťỉç çảšẽš ởř łảřğẽ mẽťảł ởbjẽçťš. ······································]';

  @override
  String get compassCalibrate =>
      '[Łởŵ ảççữřảçỹ: mởvẽ ỹởữř phởñẽ ỉñ ả fỉğữřẽ-8 ả fẽŵ ťỉmẽš. ·······················]';

  @override
  String get dirShortN => '[Ñ ··]';

  @override
  String get dirLongN => '[Ñởřťh ··]';

  @override
  String get dirShortNE => '[ÑẼ ··]';

  @override
  String get dirLongNE => '[Ñởřťhẽảšť ····]';

  @override
  String get dirShortE => '[Ẽ ··]';

  @override
  String get dirLongE => '[Ẽảšť ··]';

  @override
  String get dirShortSE => '[ŠẼ ··]';

  @override
  String get dirLongSE => '[Šởữťhẽảšť ····]';

  @override
  String get dirShortS => '[Š ··]';

  @override
  String get dirLongS => '[Šởữťh ··]';

  @override
  String get dirShortSW => '[ŠŴ ··]';

  @override
  String get dirLongSW => '[Šởữťhŵẽšť ····]';

  @override
  String get dirShortW => '[Ŵ ··]';

  @override
  String get dirLongW => '[Ŵẽšť ··]';

  @override
  String get dirShortNW => '[ÑŴ ··]';

  @override
  String get dirLongNW => '[Ñởřťhŵẽšť ····]';

  @override
  String compassHeadingPrecise(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '[$valueString° ··]';
  }

  @override
  String get compassTrueNorth => '[Ťřữẽ ñởřťh ····]';

  @override
  String compassDeclination(double value, String side) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '[Đẽçłỉñảťỉởñ $valueString° $side ······]';
  }

  @override
  String get compassNeedLocation =>
      '[Ñở łởçảťỉởñ ỹẽť, šở šhởŵỉñğ mảğñẽťỉç ñởřťh. Ťřữẽ ñởřťh ñẽẽđš ỹởữř łởçảťỉởñ ťở çởmpữťẽ đẽçłỉñảťỉởñ. ········································]';

  @override
  String get compassModelExpired =>
      '[Ťhẽ mảğñẽťỉç mởđẽł hảš ẽxpỉřẽđ, šở đẽçłỉñảťỉởñ mảỹ bẽ łẽšš ảççữřảťẽ. Płẽảšẽ ữpđảťẽ ťhẽ ảpp. ·····································]';

  @override
  String compassFieldStrength(int value) {
    return '[Fỉẽłđ $value µŤ ····]';
  }

  @override
  String get compassCameraMode => '[Fởłłởŵỉñğ řẽảř çảmẽřả ·········]';

  @override
  String get compassOptions => '[Çởmpảšš ởpťỉởñš ······]';

  @override
  String get compassOptionTrueNorth => '[Ťřữẽ ñởřťh ····]';

  @override
  String get compassOptionTrueNorthHint =>
      '[Ảđđš mảğñẽťỉç đẽçłỉñảťỉởñ fřởm ťhẽ ŴMM2025 mởđẽł, çởmpữťẽđ ởffłỉñẽ. ···························]';

  @override
  String get compassOptionHaptic => '[Vỉbřảťẽ ảť çảřđỉñảł pởỉñťš ···········]';

  @override
  String get compassOptionHapticHint =>
      '[Ả łỉğhť ťảp ẽảçh ťỉmẽ ťhẽ đỉảł pảššẽš ởñẽ ởf ťhẽ 8 đỉřẽçťỉởñš. ·························]';

  @override
  String get compassCalibrateAction => '[Çảłỉbřảťẽ ····]';

  @override
  String get calibTitle => '[Çảłỉbřảťẽ çởmpảšš ·······]';

  @override
  String get calibInstruction =>
      '[Hởłđ ťhẽ phởñẽ fỉřmłỹ ảñđ mởvẽ ỹởữř ŵřỉšť ỉñ ả fỉğữřẽ 8 ỉñ ťhẽ ảỉř. Ťhẽñ ťỉłť ťhẽ phởñẽ ữp, đởŵñ, łẽfť ảñđ řỉğhť. ··············································]';

  @override
  String get calibTip =>
      '[Šťảỹ ảŵảỹ fřởm mảğñẽťš, špẽảkẽřš, ŵỉřẽłẽšš çhảřğẽřš, mảğñẽťỉç çảšẽš ảñđ łảřğẽ mẽťảł ởbjẽçťš. ·····································]';

  @override
  String calibProgress(int percent) {
    return '[Šçảññẽđ $percent% ····]';
  }

  @override
  String calibDone(String level) {
    return '[Çảłỉbřảťỉởñ đởñẽ. Ảççữřảçỹ: $level. ············]';
  }

  @override
  String get calibFinish => '[Đởñẽ ··]';

  @override
  String get locTitle => '[Łởçảťỉởñ & ťẽłẽmẽťřỹ ········]';

  @override
  String get locIntro =>
      '[Ťữřñ ởñ łởçảťỉởñ fởř ťřữẽ ñởřťh, çởởřđỉñảťẽš, ảłťỉťữđẽ ảñđ šữñřỉšẽ / šữñšẽť ťỉmẽš. Ỹởữř łởçảťỉởñ šťảỹš ởñ ťhỉš đẽvỉçẽ. ················································]';

  @override
  String get locAllow => '[Ảłłởŵ łởçảťỉởñ ······]';

  @override
  String get locDeniedForever =>
      '[Łởçảťỉởñ pẽřmỉššỉởñ ỉš ởff. Ťữřñ ỉť ởñ ỉñ ťhẽ ảpp šẽťťỉñğš. ························]';

  @override
  String get locOpenSettings => '[Ởpẽñ šẽťťỉñğš ······]';

  @override
  String get locServiceOff => '[Đẽvỉçẽ łởçảťỉởñ ỉš ťữřñẽđ ởff. ············]';

  @override
  String get locSearching => '[Fỉñđỉñğ ỹởữř łởçảťỉởñ... ··········]';

  @override
  String get locApproximate => '[Ữšỉñğ ảppřởxỉmảťẽ łởçảťỉởñ ···········]';

  @override
  String get locDetails => '[Đẽťảỉłš ···]';

  @override
  String get locCopied => '[Çởởřđỉñảťẽš çởpỉẽđ ········]';

  @override
  String get locCopy => '[Çởpỹ ··]';

  @override
  String get locCycleFormat => '[Çhảñğẽ çởởřđỉñảťẽ fởřmảť ··········]';

  @override
  String locAccuracy(int value) {
    return '[±$value m ··]';
  }

  @override
  String locAltitude(int value) {
    return '[Ảłť. $value m ···]';
  }

  @override
  String get locOutsideVn => '[Ởữťšỉđẽ Vỉẽťñảm ······]';

  @override
  String get locOsmCredit =>
      '[Bởữñđảřỉẽš © ỞpẽñŠťřẽẽťMảp çởñťřỉbữťởřš (ỞĐbŁ) ···················]';

  @override
  String get locSectionCoords => '[Çởởřđỉñảťẽš ·····]';

  @override
  String get locSectionPlace => '[Ảđmỉñỉšťřảťỉvẽ ảřẽả ········]';

  @override
  String get locSectionAltitude => '[Ảłťỉťữđẽ ····]';

  @override
  String get locSectionMotion => '[Mởťỉởñ ···]';

  @override
  String get locSectionField => '[Mảğñẽťỉç fỉẽłđ ······]';

  @override
  String get locSectionLevel => '[Bữbbłẽ łẽvẽł ·····]';

  @override
  String get locSectionSun => '[Šữñ ··]';

  @override
  String get locSectionMoon => '[Mởởñ ··]';

  @override
  String get locFormatDd => '[Đẽçỉmảł đẽğřẽẽš ······]';

  @override
  String get locFormatDms => '[Đẽğřẽẽš mỉñữťẽš šẽçởñđš ··········]';

  @override
  String get locFormatUtm => '[ỮŤM ··]';

  @override
  String get locFormatMgrs => '[MĞŘŠ ··]';

  @override
  String get locNotAvailable => '[Ñởť ảvảỉłảbłẽ ······]';

  @override
  String get locHorizontalAccuracy => '[Hởřỉžởñťảł ảççữřảçỹ ········]';

  @override
  String get locAltGps => '[ĞPŠ (ảbởvẽ šẽả łẽvẽł) ·········]';

  @override
  String get locAltBaro => '[Bảřởmẽťẽř ····]';

  @override
  String get locBaroCalibrated => '[çảłỉbřảťẽđ ŵỉťh ĞPŠ ········]';

  @override
  String get locBaroStandard => '[ữšỉñğ šťảñđảřđ 1013 hPả ··········]';

  @override
  String get locPressure => '[Přẽššữřẽ ····]';

  @override
  String locMeters(int value) {
    return '[$value m ··]';
  }

  @override
  String locMetersPm(int value, int acc) {
    return '[$value m ±$acc m ···]';
  }

  @override
  String locHpa(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '[$valueString hPả ··]';
  }

  @override
  String get locSpeed => '[Špẽẽđ ··]';

  @override
  String locKmh(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '[$valueString km/h ··]';
  }

  @override
  String get locCourse => '[Çởữřšẽ ···]';

  @override
  String locDegrees(int value) {
    return '[$value° ··]';
  }

  @override
  String get locFieldMeasured => '[Mẽảšữřẽđ ····]';

  @override
  String get locFieldModel => '[ŴMM mởđẽł ····]';

  @override
  String locMicroTesla(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '[$valueString µŤ ··]';
  }

  @override
  String locFieldDeviation(int value) {
    return '[Ởff bỹ $value% ····]';
  }

  @override
  String get locFieldAbnormal =>
      '[Ữñữšữảł mảğñẽťỉç fỉẽłđ (ñởřmảł ỉš 25-65 µŤ): ťhẽřẽ mảỹ bẽ ả mảğñẽť ởř mẽťảł ñẽảř ťhẽ đẽvỉçẽ. ·····································]';

  @override
  String locLevelTilt(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '[Ťỉłť $valueString° ···]';
  }

  @override
  String get locLevelOk => '[Łẽvẽł ··]';

  @override
  String get locLevelHint =>
      '[Łảỹ ťhẽ đẽvỉçẽ ởñ ťhẽ šữřfảçẽ ťở çhẽçk. ················]';

  @override
  String get locRise => '[Řỉšẽ ··]';

  @override
  String get locSet => '[Šẽť ··]';

  @override
  String get locNoon => '[Šởłảř ñởởñ ····]';

  @override
  String get locTransit => '[Ťřảñšỉť ···]';

  @override
  String get locAlwaysUp => '[Ữp ảłł đảỹ ····]';

  @override
  String get locAlwaysDown => '[Đởŵñ ảłł đảỹ ·····]';

  @override
  String get locNow => '[Ñởŵ ··]';

  @override
  String locSkyPosition(int az, int alt) {
    return '[Ảžỉmữťh $az° · ẽłẽvảťỉởñ $alt° ··········]';
  }

  @override
  String locMoonIllumination(int value) {
    return '[$value% łỉť ··]';
  }

  @override
  String get locNeedLocationSky =>
      '[Łởçảťỉởñ ỉš ñẽẽđẽđ fởř řỉšẽ / šẽť ťỉmẽš. ················]';

  @override
  String get moonNew => '[Ñẽŵ mởởñ ····]';

  @override
  String get moonWaxingCrescent => '[Ŵảxỉñğ çřẽšçẽñť ······]';

  @override
  String get moonFirstQuarter => '[Fỉřšť qữảřťẽř ······]';

  @override
  String get moonWaxingGibbous => '[Ŵảxỉñğ ğỉbbởữš ······]';

  @override
  String get moonFull => '[Fữłł mởởñ ····]';

  @override
  String get moonWaningGibbous => '[Ŵảñỉñğ ğỉbbởữš ······]';

  @override
  String get moonLastQuarter => '[Łảšť qữảřťẽř ·····]';

  @override
  String get moonWaningCrescent => '[Ŵảñỉñğ çřẽšçẽñť ······]';

  @override
  String get locSourceGps => '[ĞPŠ ··]';

  @override
  String get locSourceNetwork => '[Ñẽťŵởřk ···]';

  @override
  String get locSourceFused => '[Fữšẽđ ··]';
}
