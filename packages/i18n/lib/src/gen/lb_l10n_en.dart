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

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version is no longer supported for security reasons. Download the new version to keep using the app.';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String updateAvailableBody(String phienBan) {
    return 'Version $phienBan is ready with fixes and improvements.';
  }

  @override
  String get updateAvailableBodyGeneric =>
      'A new version is ready with fixes and improvements.';

  @override
  String get updateNow => 'Update';

  @override
  String get updateLater => 'Later';

  @override
  String get updateOpenFailed =>
      'Couldn\'t open the browser. Visit compass.tsudev.com/en/download to get the new version.';

  @override
  String securityRef(String ref) {
    return 'Reference code: $ref';
  }

  @override
  String get securityCopyRef => 'Copy code';

  @override
  String get securityRefCopied => 'Reference code copied';

  @override
  String get securityRestrictedTitle => 'Some features are restricted';

  @override
  String get securityRestrictedBody =>
      'Online features are temporarily unavailable on this device. The compass keeps working as usual.';

  @override
  String get securityLockedTitle => 'The app is locked on this device';

  @override
  String get securityLockedBody =>
      'For security reasons, the app can\'t continue on this device. If you think this is a mistake, send an appeal with the reference code below.';

  @override
  String get securityAppeal => 'Send an appeal';

  @override
  String get securityAppealOpenFailed =>
      'Couldn\'t open the browser. Visit compass.tsudev.com/en/appeal to send an appeal.';

  @override
  String get wpSaveHere => 'Save location';

  @override
  String get wpAddManual => 'Enter coordinates';

  @override
  String get wpNewTitle => 'New waypoint';

  @override
  String get wpEditTitle => 'Edit waypoint';

  @override
  String get wpName => 'Name';

  @override
  String get wpLat => 'Latitude';

  @override
  String get wpLon => 'Longitude';

  @override
  String get wpAlt => 'Altitude (m, optional)';

  @override
  String get wpNote => 'Note';

  @override
  String get wpPhotos => 'Photos';

  @override
  String get wpAddPhoto => 'Add photo';

  @override
  String get wpRemovePhoto => 'Remove photo';

  @override
  String wpPhotoSemantics(int index) {
    return 'Waypoint photo $index';
  }

  @override
  String get wpPhotoHint =>
      'Photos are resized and stripped of location / camera data before saving.';

  @override
  String get wpPhotoError => 'Couldn\'t read this photo.';

  @override
  String get wpSave => 'Save';

  @override
  String get wpCancel => 'Cancel';

  @override
  String get wpDelete => 'Delete';

  @override
  String wpDeleteConfirm(String name) {
    return 'Delete \"$name\" and its photos? This can\'t be undone.';
  }

  @override
  String get wpUseCurrent => 'Use current location';

  @override
  String get wpLocating => 'Getting location...';

  @override
  String get wpLocationNeeded =>
      'Location permission is needed to save where you are.';

  @override
  String get wpGrant => 'Allow location';

  @override
  String get wpErrNameEmpty => 'Enter a name';

  @override
  String wpErrNameLong(int max) {
    return 'Name can be at most $max characters';
  }

  @override
  String get wpErrLat => 'Latitude must be between -90 and 90';

  @override
  String get wpErrLon => 'Longitude must be between -180 and 180';

  @override
  String get wpErrAlt => 'Invalid altitude';

  @override
  String wpErrNoteLong(int max) {
    return 'Note can be at most $max characters';
  }

  @override
  String get wpNavigate => 'Navigate';

  @override
  String get wpShare => 'Share';

  @override
  String get wpEdit => 'Edit';

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
    return '$distance away';
  }

  @override
  String wpBearing(int value) {
    return 'Bearing $value° (true north)';
  }

  @override
  String wpTurn(int value, String side) {
    return 'Turn $value° $side';
  }

  @override
  String get wpLeft => 'left';

  @override
  String get wpRight => 'right';

  @override
  String get wpAhead => 'Straight ahead';

  @override
  String get wpArrived => 'You have arrived';

  @override
  String get wpNoCompass =>
      'No compass sensor: follow the bearing below with another compass.';

  @override
  String get wpWaitingGps => 'Waiting for GPS...';

  @override
  String wpAccuracy(int value) {
    return 'Location accuracy ±$value m';
  }

  @override
  String wpArrowSemantics(String name, String distance) {
    return 'Arrow pointing to $name, $distance';
  }

  @override
  String wpCreated(String date) {
    return 'Created $date';
  }

  @override
  String get wpCoords => 'Coordinates';

  @override
  String wpAltValue(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return 'Altitude $valueString m';
  }

  @override
  String get wpCopyCoords => 'Copy coordinates';

  @override
  String get wpImport => 'Import GPX / KML';

  @override
  String get wpExportGpx => 'Export GPX';

  @override
  String get wpExportKml => 'Export KML';

  @override
  String get wpMore => 'More options';

  @override
  String wpImportResult(int added, int updated, int skipped) {
    return 'Added $added, updated $updated, skipped $skipped waypoints.';
  }

  @override
  String get wpImportError => 'Couldn\'t read the file: not valid GPX / KML.';

  @override
  String get wpImportEmpty => 'The file has no waypoints.';

  @override
  String get wpFileError => 'Couldn\'t open or save the file.';

  @override
  String get wpExported => 'File saved.';

  @override
  String wpUnnamed(int index) {
    return 'Waypoint $index';
  }

  @override
  String get wpShareTitle => 'Share waypoint';

  @override
  String get wpShareExpiry => 'Link expires after';

  @override
  String wpDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String wpShareInfo(int max) {
    return 'The link contains the name, coordinates, altitude and up to $max characters of the note, without photos. Anyone with the link can see it until it expires.';
  }

  @override
  String get wpCopyLink => 'Copy link';

  @override
  String get wpCopied => 'Copied';

  @override
  String get wpSendLink => 'Send link';

  @override
  String get wpQrSemantics => 'QR code of the share link';

  @override
  String get wpShareDisabled => 'Sharing is temporarily turned off.';

  @override
  String get wpReceivedTitle => 'Shared waypoint';

  @override
  String wpReceivedExpires(String date) {
    return 'Link expires $date';
  }

  @override
  String get wpReceivedSave => 'Save to Waypoints';

  @override
  String get wpReceivedSaved => 'Saved to Waypoints.';

  @override
  String get wpReceivedUntrusted =>
      'Content is set by the sender and isn\'t verified by the app.';

  @override
  String get wpLinkBroken => 'This link is invalid or was cut off when sent.';

  @override
  String get wpLinkExpired =>
      'This link has expired. Ask the sender to share it again.';

  @override
  String get wpLinkNewer =>
      'This link was made by a newer version. Please update the app.';

  @override
  String get wpGoWaypoints => 'Open waypoints';

  @override
  String get wpSafeTitle => 'Export saved waypoints';

  @override
  String get wpSafeBody =>
      'In safe mode the waypoint list is locked. You can still export all waypoints to a GPX file to keep them safe.';

  @override
  String get wpSafeReadError => 'Couldn\'t read saved waypoints.';

  @override
  String wpSafeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count waypoints',
      one: '1 waypoint',
      zero: 'No waypoints',
    );
    return '$_temp0';
  }

  @override
  String get mapMyLocation => 'My location';

  @override
  String get mapNoLocation => 'No location yet - waiting for GPS.';

  @override
  String get mapFollowHeading => 'Rotate map with heading';

  @override
  String get mapNorthUp => 'North up';

  @override
  String get mapOffline => 'Offline maps';

  @override
  String get mapOfflineIntro =>
      'Download map areas ahead of time to use them without a connection: airplane mode, mountains, at sea.';

  @override
  String get mapOfflineOverview => 'Vietnam overview';

  @override
  String get mapOfflineOverviewDesc =>
      'The whole country including the Hoàng Sa and Trường Sa archipelagos; main roads, province and city names.';

  @override
  String get mapOfflineCurrent => 'Current view';

  @override
  String mapOfflineCurrentDesc(int tiles) {
    return '$tiles map tiles, detailed down to streets.';
  }

  @override
  String mapOfflineTooLarge(int tiles) {
    return 'This area is too large ($tiles tiles). Zoom in on the map, then try again.';
  }

  @override
  String get mapOfflineNoView =>
      'Open the Map tab and move to the area you want.';

  @override
  String get mapOfflineDownload => 'Download';

  @override
  String mapOfflineDownloading(int done, int total) {
    return 'Downloading $done/$total';
  }

  @override
  String get mapOfflineDone => 'Map area downloaded.';

  @override
  String get mapOfflineFailed =>
      'Download didn\'t finish - check your connection and try again.';

  @override
  String get mapOfflineSaved => 'Downloaded areas';

  @override
  String get mapOfflineEmpty => 'No areas yet.';

  @override
  String get mapOfflineDelete => 'Delete area';

  @override
  String mapOfflineDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String mapOfflineStorage(double mb) {
    final intl.NumberFormat mbNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String mbString = mbNumberFormat.format(mb);

    return 'Using $mbString MB on this device';
  }

  @override
  String mapOfflineAreaName(String date) {
    return 'Area $date';
  }

  @override
  String mapOfflineZoom(int from, int to) {
    return 'Detail levels $from-$to';
  }

  @override
  String get arOpen => 'View heading through camera';

  @override
  String get arTitle => 'Camera AR';

  @override
  String get arPermission =>
      'Camera access lets the app overlay headings and saved points on the live view. Images stay on screen only: nothing is captured, stored or sent.';

  @override
  String get arPermissionBlocked =>
      'Camera access is off. Turn it back on in your device Settings to use Camera AR.';

  @override
  String get arGrant => 'Allow camera';

  @override
  String get arOpenSettings => 'Open Settings';

  @override
  String get arNoCamera =>
      'Couldn\'t open the rear camera - the device has none or another app is using it.';

  @override
  String get arRetry => 'Try again';

  @override
  String get arHoldUpright =>
      'Hold the phone upright with the camera facing forward.';

  @override
  String get arCalibrate => 'Low compass accuracy - calibrate with a figure 8.';

  @override
  String get arNoLocation =>
      'No location yet - saved points appear once GPS is ready.';

  @override
  String arDistanceM(int value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString m';
  }

  @override
  String arDistanceKm(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$valueString km';
  }

  @override
  String arHeadingLabel(int degrees) {
    return 'Camera heading $degrees degrees';
  }

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get noticeTitle => 'Your data';

  @override
  String get noticeDevice =>
      'Waypoints, settings and your last location are stored encrypted on this device and never sent to our servers.';

  @override
  String get noticeSensors =>
      'Location, camera and sensors are processed only on this device. Permissions are asked only when you use a feature that needs them.';

  @override
  String get noticeSecurity =>
      'If you agree, the app sends technical security data to fight fraud and tampered copies: a random installation ID, device model, Android and app version, Google\'s device verification result, environment signals (root, debugger) and your IP address. The freeRASP security library (Talsec) sends similar environment information.';

  @override
  String get noticeRetention =>
      'Security events are kept for 180 days and IP addresses are truncated after 90 days. We never sell data or use tracking ads.';

  @override
  String get noticeRights =>
      'You can view, export or delete your data and withdraw consent at any time in Settings > Privacy.';

  @override
  String get noticePolicy => 'Read the full privacy policy';

  @override
  String get consentAccept => 'Agree and start';

  @override
  String get consentOffline => 'Use offline only';

  @override
  String get consentOfflineHint =>
      'Offline: the compass, downloaded maps and waypoints still work fully, but you won\'t receive configuration or security alerts from the server.';

  @override
  String get privacyOnline => 'Online security connection';

  @override
  String get privacyOnlineHint =>
      'Sends technical security data and receives signed configuration. Turning it off withdraws consent; the security library stops completely from the next app launch.';

  @override
  String get privacyCrash => 'Send crash reports';

  @override
  String get privacyCrashHint =>
      'When the app hits an error, sends the error type, the encoded code trace, and the app and Android versions so we can fix it. Never sends your location, waypoints or anything you type; kept for 90 days.';

  @override
  String get privacyCrashNeedsOnline =>
      'Turn on Online security connection first.';

  @override
  String privacyChoiceAt(String date) {
    return 'Choice recorded on $date';
  }

  @override
  String get privacyOnDevice => 'Data on this device';

  @override
  String privacyWaypoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved waypoints',
      one: '1 saved waypoint',
      zero: 'No saved waypoints',
    );
    return '$_temp0';
  }

  @override
  String get privacyExport => 'Export data (JSON)';

  @override
  String get privacyExportDone => 'Data file saved';

  @override
  String get privacyExportFailed => 'Data file not saved';

  @override
  String get privacyDeleteAll => 'Delete all data on this device';

  @override
  String get privacyDeleteTitle => 'Delete all data?';

  @override
  String get privacyDeleteBody =>
      'Waypoints, offline maps, settings and device keys will be permanently deleted and the app will close. Export your data first if you want to keep it.';

  @override
  String get privacyDeleteConfirm => 'Delete permanently';

  @override
  String get privacyOnServer => 'Data on our servers';

  @override
  String get privacyServerBody =>
      'Our servers only keep technical security data linked to the device ID below, for the periods stated in the policy.';

  @override
  String privacyDeviceId(String id) {
    return 'Device ID: $id';
  }

  @override
  String get privacyNoDeviceId =>
      'This device is not registered with our servers';

  @override
  String get privacyCopied => 'Device ID copied';

  @override
  String get privacyRequestDelete => 'Request deletion of server data';

  @override
  String get privacyRequestSubject => 'La bàn data deletion request';

  @override
  String privacyRequestBody(String id) {
    return 'Device ID: $id\nPlease delete the data linked to this device.\n';
  }

  @override
  String privacyMailFailed(String email) {
    return 'Couldn\'t open a mail app - please write to $email';
  }

  @override
  String get privacyPermissions => 'System permissions';

  @override
  String get privacyPermissionsBody =>
      'Location and camera are managed by the system - revoke them any time in the app settings.';

  @override
  String get privacyOpenSettings => 'Open app settings';

  @override
  String get devModeBlockedTitle => 'Turn off developer mode';

  @override
  String get devModeBlockedBody =>
      'To protect your data and account, Compass doesn\'t run while Developer options or USB / wireless debugging are on. Turn them off, then come back to the app.';

  @override
  String get devModeStatusTitle => 'Currently on';

  @override
  String get devModeItemOptions => 'Developer options';

  @override
  String get devModeItemUsb => 'USB debugging';

  @override
  String get devModeItemWifi => 'Wireless debugging';

  @override
  String get devModeHowTo =>
      'Settings > System (or Additional settings) > Developer options > switch the top toggle off.';

  @override
  String get devModeOpenSettings => 'Open Developer options';

  @override
  String get devModeOpenFailed =>
      'Couldn\'t open settings - open your phone\'s Settings app.';

  @override
  String get devModeRecheck => 'Check again';

  @override
  String get devModeServerOnly =>
      'The server still sees developer mode - connect to the internet, then tap Check again.';

  @override
  String get m1ProTitle => 'Compass Pro';

  @override
  String get m1ProTagline => 'Remove ads and help Compass keep growing.';

  @override
  String get m1BenefitNoAds => 'No ads on any screen';

  @override
  String get m1BenefitFree =>
      'Free features stay free: compass, coordinates, waypoints, sharing, offline maps, AR camera';

  @override
  String get m1BenefitNew => 'Get new Pro features as soon as they launch';

  @override
  String get m1BenefitSupport => 'Support an independent developer';

  @override
  String get m1PlanYear => 'Yearly';

  @override
  String get m1PlanMonth => 'Monthly';

  @override
  String get m1PlanLifetime => 'Lifetime';

  @override
  String m1PricePerYear(String price) {
    return '$price / year';
  }

  @override
  String m1PricePerMonth(String price) {
    return '$price / month';
  }

  @override
  String m1PriceOnce(String price) {
    return '$price - one-time payment';
  }

  @override
  String m1TrialBadge(int days) {
    return '$days-day free trial';
  }

  @override
  String get m1Continue => 'Continue';

  @override
  String get m1StartTrial => 'Start free trial';

  @override
  String get m1Restore => 'Restore purchases';

  @override
  String get m1Manage => 'Manage subscription on Google Play';

  @override
  String get m1ManageFailed => 'Couldn\'t open Google Play on this device.';

  @override
  String m1TermsSub(String price) {
    return 'The subscription renews automatically at $price until you cancel. Cancel anytime in Google Play > Payments & subscriptions, at least 24 hours before the current period ends to avoid being charged for the next one. Payment is charged to your Google Play account when you confirm the purchase.';
  }

  @override
  String m1TermsTrial(int days, String price) {
    return 'After the $days-day trial you will be charged $price unless you cancel before the trial ends.';
  }

  @override
  String get m1TermsLifetime =>
      'One-time payment, no auto-renewal. Use it on any device signed in to the same Google account (Restore purchases).';

  @override
  String get m1Loading => 'Loading plans from Google Play…';

  @override
  String get m1Unavailable =>
      'Google Play isn\'t available on this device or the plans aren\'t on sale yet. Please try again later.';

  @override
  String get m1Retry => 'Try again';

  @override
  String get m1Pending =>
      'Google Play is waiting for you to complete payment. Compass Pro turns on once payment goes through.';

  @override
  String get m1Verifying => 'Confirming your purchase…';

  @override
  String get m1Success => 'Thank you! Compass Pro is now on.';

  @override
  String get m1Active => 'You\'re using Compass Pro';

  @override
  String m1ActiveUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get m1ActiveLifetime => 'Lifetime plan';

  @override
  String get m1Grace =>
      'Confirming your renewal with Google Play - Pro stays on meanwhile.';

  @override
  String get m1ErrNetwork =>
      'Couldn\'t reach the server. Your purchase is kept and will be confirmed automatically when you\'re online.';

  @override
  String get m1ErrStore =>
      'Google Play couldn\'t start the purchase. Please try again.';

  @override
  String get m1ErrToken =>
      'The purchase couldn\'t be verified with Google Play. If you were charged, Google refunds it automatically within 3 days.';

  @override
  String get m1ErrShared =>
      'This purchase is in use on too many devices. If this is a mistake, send an appeal with your device code.';

  @override
  String get m1ErrNotPlay =>
      'This copy wasn\'t installed from Google Play, so it can\'t receive Pro. Install Compass from Google Play, then tap Restore purchases.';

  @override
  String get m1ErrServer =>
      'The server couldn\'t confirm the purchase yet. Please try again in a few minutes.';

  @override
  String get m1ErrNothing =>
      'No purchases found for the Google account signed in to Play.';

  @override
  String get m1Dismiss => 'Dismiss';

  @override
  String get m1SettingsSubFree => 'Remove ads, support development';

  @override
  String get m1SettingsSubPro => 'Active';

  @override
  String get a9FieldNormal => 'Field normal - no magnetic interference nearby.';

  @override
  String get a9SrcCompass => 'Compass (magnetometer)';

  @override
  String get a9SrcGps => 'GPS course';

  @override
  String get a9SrcSun => 'Sun';

  @override
  String get a9SrcMoon => 'Moon';

  @override
  String get a9SrcManual => 'Set by hand';

  @override
  String a9SrcWithGyro(String nguon) {
    return '$nguon + gyro';
  }

  @override
  String a9SrcLine(String nguon, int saiSo) {
    return 'Source: $nguon · ±$saiSo°';
  }

  @override
  String get a9NoMagTitle => 'This phone has no magnetic compass';

  @override
  String get a9NoMagBody =>
      'You can still get a direction: walk a few steps to use the GPS course, or set it from the Sun, the Moon or a landmark whose direction you know.';

  @override
  String get a9BtnSun => 'Use the Sun\'s shadow';

  @override
  String get a9BtnMoon => 'Point at the Moon';

  @override
  String get a9BtnManual => 'Set direction by hand';

  @override
  String get a9BtnDevice => 'Your device';

  @override
  String get a9BtnSet => 'Set direction';

  @override
  String get a9SunHelp =>
      'Stand something upright (a pen, a stick). Lay the phone flat along its shadow, top edge pointing away from the object, then tap Set direction. Never look straight at the Sun.';

  @override
  String get a9MoonHelp =>
      'Point the top edge of the phone straight at the Moon, then tap Set direction.';

  @override
  String get a9ManualHelp =>
      'Point the top edge of the phone at a landmark whose direction you know (e.g. a road running north), drag to that bearing, then tap Set direction.';

  @override
  String get a9SkyLow =>
      'The Sun and Moon are below the horizon or your location is unknown - use GPS or set the direction by hand.';

  @override
  String get a9SetFailed => 'Couldn\'t set it: the Sun or Moon is too low now.';

  @override
  String get a9Reanchor =>
      'It\'s been a while - the direction may have drifted. Set it again.';

  @override
  String get a9StaticAnchor =>
      'No gyroscope: keep the phone exactly as aligned; set it again after turning.';

  @override
  String get a9Walking => 'Walking: the GPS course is used automatically.';

  @override
  String get a9DeviceTitle => 'Your device';

  @override
  String get a9DeviceIntro =>
      'The app checks once which sensors this phone has (yes / no only, no device IDs) to pick the best way to find a direction.';

  @override
  String get a9DeviceProbing => 'Checking sensors…';

  @override
  String get a9SensMag => 'Magnetometer (compass)';

  @override
  String get a9SensGyro => 'Gyroscope';

  @override
  String get a9SensAccel => 'Accelerometer';

  @override
  String get a9SensGameRot => 'System rotation fusion';

  @override
  String get a9SensBaro => 'Barometer (altitude)';

  @override
  String get a9SensGps => 'GPS';

  @override
  String get a9SensCamera => 'Rear camera';

  @override
  String get a9Yes => 'Yes';

  @override
  String get a9No => 'No';

  @override
  String get a9SourcesTitle =>
      'Direction sources available (in priority order)';

  @override
  String get a9LiteOn =>
      'Lite mode is on: the dial skips smooth rotation so the phone stays responsive.';

  @override
  String get a9LiteOff =>
      'Lite mode: off - this phone handles the full effects.';

  @override
  String get appTitlePro => 'Compass Pro';

  @override
  String get m2LicenseTitle => 'Compass Pro license';

  @override
  String get m2LicenseOk =>
      'Verified by Google Play - all Pro features unlocked';

  @override
  String get m2LicenseMissing =>
      'Not verified - tap to get the official copy from Google Play';

  @override
  String get m2LicenseFixFail =>
      'Couldn\'t open Google Play. Install Compass Pro from Google Play, then reopen the app.';

  @override
  String get m2LicenseFixDone => 'License re-check requested.';

  @override
  String get m2bMoveTitle => 'Move to Compass Pro';

  @override
  String get m2bMoveSubtitle =>
      'Compass Pro is installed - send waypoints, photos and settings to it';

  @override
  String get m2bMoveIntro =>
      'Send your waypoints (with photos), your offline map areas and your display choices to Compass Pro on this device. Data goes straight from app to app, never over the network; this app keeps its own copy.';

  @override
  String m2bMoveCounts(int points, int photos, int areas) {
    return '$points waypoints · $photos photos · $areas offline areas';
  }

  @override
  String get m2bMoveSend => 'Send to Compass Pro';

  @override
  String get m2bMoveOpenPro => 'Open Compass Pro';

  @override
  String get m2bMoveNotInstalled =>
      'Official Compass Pro from Google Play is not installed on this device.';

  @override
  String get m2bMoveGetPro => 'See Compass Pro on Google Play';

  @override
  String get m2bMoveFailed =>
      'Could not send. Use Settings > Privacy > Export data, then pick that file in Compass Pro.';

  @override
  String get m2bImportTitle => 'Import from Compass';

  @override
  String get m2bImportSubtitle =>
      'Bring waypoints, photos and settings from the free app';

  @override
  String get m2bImportIntro =>
      'Take your data from Compass (free app) on this device, or pick a file saved with Settings > Privacy > Export data. You review everything before it is imported.';

  @override
  String get m2bImportFromFree => 'Take from Compass on this device';

  @override
  String get m2bImportFreeMissing =>
      'The official free Compass app is not on this device - pick an export file instead.';

  @override
  String get m2bImportFile => 'Pick an export file';

  @override
  String get m2bImportConfirmTitle => 'Review before importing';

  @override
  String m2bImportPlan(int added, int updated, int same) {
    return '$added new · $updated updated · $same already here';
  }

  @override
  String m2bImportPhotos(int count) {
    return '$count photos with the new waypoints';
  }

  @override
  String get m2bImportSettings =>
      'Use the language, theme and compass options of the free app';

  @override
  String m2bImportSkipped(int count) {
    return '$count broken items will be skipped';
  }

  @override
  String get m2bImportDo => 'Import';

  @override
  String m2bImportDone(int added, int updated) {
    return 'Imported $added new and updated $updated waypoints.';
  }

  @override
  String get m2bImportBadFile => 'This file is not valid Compass data.';

  @override
  String get m2bImportEmpty => 'Nothing to import.';

  @override
  String get m2bImportNoPhotos =>
      'A personal data export has no photos or map areas - only waypoints and settings are imported.';

  @override
  String get m2bAreasTitle => 'Download offline areas again';

  @override
  String get m2bAreasIntro =>
      'Downloaded maps stay inside each app, so Compass Pro needs to download them again (network needed).';

  @override
  String get m2bAreaDone => 'Downloaded';
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

  @override
  String get updateRequiredTitle => '[Ữpđảťẽ řẽqữỉřẽđ ······]';

  @override
  String get updateRequiredBody =>
      '[Ťhỉš vẽřšỉởñ ỉš ñở łởñğẽř šữppởřťẽđ fởř šẽçữřỉťỹ řẽảšởñš. Đởŵñłởảđ ťhẽ ñẽŵ vẽřšỉởñ ťở kẽẽp ữšỉñğ ťhẽ ảpp. ··········································]';

  @override
  String get updateAvailableTitle => '[Ả ñẽŵ vẽřšỉởñ ỉš ảvảỉłảbłẽ ···········]';

  @override
  String updateAvailableBody(String phienBan) {
    return '[Vẽřšỉởñ $phienBan ỉš řẽảđỹ ŵỉťh fỉxẽš ảñđ ỉmpřởvẽmẽñťš. ···················]';
  }

  @override
  String get updateAvailableBodyGeneric =>
      '[Ả ñẽŵ vẽřšỉởñ ỉš řẽảđỹ ŵỉťh fỉxẽš ảñđ ỉmpřởvẽmẽñťš. ·····················]';

  @override
  String get updateNow => '[Ữpđảťẽ ···]';

  @override
  String get updateLater => '[Łảťẽř ··]';

  @override
  String get updateOpenFailed =>
      '[Çởữłđñ\'ť ởpẽñ ťhẽ břởŵšẽř. Vỉšỉť çởmpảšš.ťšữđẽv.çởm/ẽñ/đởŵñłởảđ ťở ğẽť ťhẽ ñẽŵ vẽřšỉởñ. ···································]';

  @override
  String securityRef(String ref) {
    return '[Řẽfẽřẽñçẽ çởđẽ: $ref ·······]';
  }

  @override
  String get securityCopyRef => '[Çởpỹ çởđẽ ····]';

  @override
  String get securityRefCopied => '[Řẽfẽřẽñçẽ çởđẽ çởpỉẽđ ·········]';

  @override
  String get securityRestrictedTitle =>
      '[Šởmẽ fẽảťữřẽš ảřẽ řẽšťřỉçťẽđ ············]';

  @override
  String get securityRestrictedBody =>
      '[Ởñłỉñẽ fẽảťữřẽš ảřẽ ťẽmpởřảřỉłỹ ữñảvảỉłảbłẽ ởñ ťhỉš đẽvỉçẽ. Ťhẽ çởmpảšš kẽẽpš ŵởřkỉñğ ảš ữšữảł. ······································]';

  @override
  String get securityLockedTitle =>
      '[Ťhẽ ảpp ỉš łởçkẽđ ởñ ťhỉš đẽvỉçẽ ·············]';

  @override
  String get securityLockedBody =>
      '[Fởř šẽçữřỉťỹ řẽảšởñš, ťhẽ ảpp çảñ\'ť çởñťỉñữẽ ởñ ťhỉš đẽvỉçẽ. Ỉf ỹởữ ťhỉñk ťhỉš ỉš ả mỉšťảkẽ, šẽñđ ảñ ảppẽảł ŵỉťh ťhẽ řẽfẽřẽñçẽ çởđẽ bẽłởŵ. ························································]';

  @override
  String get securityAppeal => '[Šẽñđ ảñ ảppẽảł ······]';

  @override
  String get securityAppealOpenFailed =>
      '[Çởữłđñ\'ť ởpẽñ ťhẽ břởŵšẽř. Vỉšỉť çởmpảšš.ťšữđẽv.çởm/ẽñ/ảppẽảł ťở šẽñđ ảñ ảppẽảł. ································]';

  @override
  String get wpSaveHere => '[Šảvẽ łởçảťỉởñ ······]';

  @override
  String get wpAddManual => '[Ẽñťẽř çởởřđỉñảťẽš ·······]';

  @override
  String get wpNewTitle => '[Ñẽŵ ŵảỹpởỉñť ·····]';

  @override
  String get wpEditTitle => '[Ẽđỉť ŵảỹpởỉñť ······]';

  @override
  String get wpName => '[Ñảmẽ ··]';

  @override
  String get wpLat => '[Łảťỉťữđẽ ····]';

  @override
  String get wpLon => '[Łởñğỉťữđẽ ····]';

  @override
  String get wpAlt => '[Ảłťỉťữđẽ (m, ởpťỉởñảł) ·········]';

  @override
  String get wpNote => '[Ñởťẽ ··]';

  @override
  String get wpPhotos => '[Phởťởš ···]';

  @override
  String get wpAddPhoto => '[Ảđđ phởťở ····]';

  @override
  String get wpRemovePhoto => '[Řẽmởvẽ phởťở ·····]';

  @override
  String wpPhotoSemantics(int index) {
    return '[Ŵảỹpởỉñť phởťở $index ······]';
  }

  @override
  String get wpPhotoHint =>
      '[Phởťởš ảřẽ řẽšỉžẽđ ảñđ šťřỉppẽđ ởf łởçảťỉởñ / çảmẽřả đảťả bẽfởřẽ šảvỉñğ. ·····························]';

  @override
  String get wpPhotoError => '[Çởữłđñ\'ť řẽảđ ťhỉš phởťở. ··········]';

  @override
  String get wpSave => '[Šảvẽ ··]';

  @override
  String get wpCancel => '[Çảñçẽł ···]';

  @override
  String get wpDelete => '[Đẽłẽťẽ ···]';

  @override
  String wpDeleteConfirm(String name) {
    return '[Đẽłẽťẽ \"$name\" ảñđ ỉťš phởťởš? Ťhỉš çảñ\'ť bẽ ữñđởñẽ. ···················]';
  }

  @override
  String get wpUseCurrent => '[Ữšẽ çữřřẽñť łởçảťỉởñ ········]';

  @override
  String get wpLocating => '[Ğẽťťỉñğ łởçảťỉởñ... ········]';

  @override
  String get wpLocationNeeded =>
      '[Łởçảťỉởñ pẽřmỉššỉởñ ỉš ñẽẽđẽđ ťở šảvẽ ŵhẽřẽ ỹởữ ảřẽ. ·····················]';

  @override
  String get wpGrant => '[Ảłłởŵ łởçảťỉởñ ······]';

  @override
  String get wpErrNameEmpty => '[Ẽñťẽř ả ñảmẽ ·····]';

  @override
  String wpErrNameLong(int max) {
    return '[Ñảmẽ çảñ bẽ ảť mởšť $max çhảřảçťẽřš ·············]';
  }

  @override
  String get wpErrLat => '[Łảťỉťữđẽ mữšť bẽ bẽťŵẽẽñ -90 ảñđ 90 ··············]';

  @override
  String get wpErrLon =>
      '[Łởñğỉťữđẽ mữšť bẽ bẽťŵẽẽñ -180 ảñđ 180 ················]';

  @override
  String get wpErrAlt => '[Ỉñvảłỉđ ảłťỉťữđẽ ·······]';

  @override
  String wpErrNoteLong(int max) {
    return '[Ñởťẽ çảñ bẽ ảť mởšť $max çhảřảçťẽřš ·············]';
  }

  @override
  String get wpNavigate => '[Ñảvỉğảťẽ ····]';

  @override
  String get wpShare => '[Šhảřẽ ··]';

  @override
  String get wpEdit => '[Ẽđỉť ··]';

  @override
  String wpMeters(int value) {
    return '[$value m ··]';
  }

  @override
  String wpKilometers(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '[$valueString km ··]';
  }

  @override
  String wpAway(String distance) {
    return '[$distance ảŵảỹ ··]';
  }

  @override
  String wpBearing(int value) {
    return '[Bẽảřỉñğ $value° (ťřữẽ ñởřťh) ·········]';
  }

  @override
  String wpTurn(int value, String side) {
    return '[Ťữřñ $value° $side ···]';
  }

  @override
  String get wpLeft => '[łẽfť ··]';

  @override
  String get wpRight => '[řỉğhť ··]';

  @override
  String get wpAhead => '[Šťřảỉğhť ảhẽảđ ······]';

  @override
  String get wpArrived => '[Ỹởữ hảvẽ ảřřỉvẽđ ·······]';

  @override
  String get wpNoCompass =>
      '[Ñở çởmpảšš šẽñšởř: fởłłởŵ ťhẽ bẽảřỉñğ bẽłởŵ ŵỉťh ảñởťhẽř çởmpảšš. ··························]';

  @override
  String get wpWaitingGps => '[Ŵảỉťỉñğ fởř ĞPŠ... ········]';

  @override
  String wpAccuracy(int value) {
    return '[Łởçảťỉởñ ảççữřảçỹ ±$value m ·········]';
  }

  @override
  String wpArrowSemantics(String name, String distance) {
    return '[Ảřřởŵ pởỉñťỉñğ ťở $name, $distance ········]';
  }

  @override
  String wpCreated(String date) {
    return '[Çřẽảťẽđ $date ····]';
  }

  @override
  String get wpCoords => '[Çởởřđỉñảťẽš ·····]';

  @override
  String wpAltValue(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '[Ảłťỉťữđẽ $valueString m ·····]';
  }

  @override
  String get wpCopyCoords => '[Çởpỹ çởởřđỉñảťẽš ·······]';

  @override
  String get wpImport => '[Ỉmpởřť ĞPX / KMŁ ·······]';

  @override
  String get wpExportGpx => '[Ẽxpởřť ĞPX ····]';

  @override
  String get wpExportKml => '[Ẽxpởřť KMŁ ····]';

  @override
  String get wpMore => '[Mởřẽ ởpťỉởñš ·····]';

  @override
  String wpImportResult(int added, int updated, int skipped) {
    return '[Ảđđẽđ $added, ữpđảťẽđ $updated, škỉppẽđ $skipped ŵảỹpởỉñťš. ···············]';
  }

  @override
  String get wpImportError =>
      '[Çởữłđñ\'ť řẽảđ ťhẽ fỉłẽ: ñởť vảłỉđ ĞPX / KMŁ. ··················]';

  @override
  String get wpImportEmpty => '[Ťhẽ fỉłẽ hảš ñở ŵảỹpởỉñťš. ···········]';

  @override
  String get wpFileError => '[Çởữłđñ\'ť ởpẽñ ởř šảvẽ ťhẽ fỉłẽ. ·············]';

  @override
  String get wpExported => '[Fỉłẽ šảvẽđ. ·····]';

  @override
  String wpUnnamed(int index) {
    return '[Ŵảỹpởỉñť $index ····]';
  }

  @override
  String get wpShareTitle => '[Šhảřẽ ŵảỹpởỉñť ······]';

  @override
  String get wpShareExpiry => '[Łỉñk ẽxpỉřẽš ảfťẽř ········]';

  @override
  String wpDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count đảỹš',
      one: '1 đảỹ',
    );
    return '[$_temp0 ·············]';
  }

  @override
  String wpShareInfo(int max) {
    return '[Ťhẽ łỉñk çởñťảỉñš ťhẽ ñảmẽ, çởởřđỉñảťẽš, ảłťỉťữđẽ ảñđ ữp ťở $max çhảřảçťẽřš ởf ťhẽ ñởťẽ, ŵỉťhởữť phởťởš. Ảñỹởñẽ ŵỉťh ťhẽ łỉñk çảñ šẽẽ ỉť ữñťỉł ỉť ẽxpỉřẽš. ····························································]';
  }

  @override
  String get wpCopyLink => '[Çởpỹ łỉñk ····]';

  @override
  String get wpCopied => '[Çởpỉẽđ ···]';

  @override
  String get wpSendLink => '[Šẽñđ łỉñk ····]';

  @override
  String get wpQrSemantics => '[QŘ çởđẽ ởf ťhẽ šhảřẽ łỉñk ··········]';

  @override
  String get wpShareDisabled =>
      '[Šhảřỉñğ ỉš ťẽmpởřảřỉłỹ ťữřñẽđ ởff. ··············]';

  @override
  String get wpReceivedTitle => '[Šhảřẽđ ŵảỹpởỉñť ······]';

  @override
  String wpReceivedExpires(String date) {
    return '[Łỉñk ẽxpỉřẽš $date ······]';
  }

  @override
  String get wpReceivedSave => '[Šảvẽ ťở Ŵảỹpởỉñťš ·······]';

  @override
  String get wpReceivedSaved => '[Šảvẽđ ťở Ŵảỹpởỉñťš. ········]';

  @override
  String get wpReceivedUntrusted =>
      '[Çởñťẽñť ỉš šẽť bỹ ťhẽ šẽñđẽř ảñđ ỉšñ\'ť vẽřỉfỉẽđ bỹ ťhẽ ảpp. ························]';

  @override
  String get wpLinkBroken =>
      '[Ťhỉš łỉñk ỉš ỉñvảłỉđ ởř ŵảš çữť ởff ŵhẽñ šẽñť. ···················]';

  @override
  String get wpLinkExpired =>
      '[Ťhỉš łỉñk hảš ẽxpỉřẽđ. Ảšk ťhẽ šẽñđẽř ťở šhảřẽ ỉť ảğảỉñ. ·······················]';

  @override
  String get wpLinkNewer =>
      '[Ťhỉš łỉñk ŵảš mảđẽ bỹ ả ñẽŵẽř vẽřšỉởñ. Płẽảšẽ ữpđảťẽ ťhẽ ảpp. ·························]';

  @override
  String get wpGoWaypoints => '[Ởpẽñ ŵảỹpởỉñťš ······]';

  @override
  String get wpSafeTitle => '[Ẽxpởřť šảvẽđ ŵảỹpởỉñťš ·········]';

  @override
  String get wpSafeBody =>
      '[Ỉñ šảfẽ mởđẽ ťhẽ ŵảỹpởỉñť łỉšť ỉš łởçkẽđ. Ỹởữ çảñ šťỉłł ẽxpởřť ảłł ŵảỹpởỉñťš ťở ả ĞPX fỉłẽ ťở kẽẽp ťhẽm šảfẽ. ············································]';

  @override
  String get wpSafeReadError =>
      '[Çởữłđñ\'ť řẽảđ šảvẽđ ŵảỹpởỉñťš. ············]';

  @override
  String wpSafeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ŵảỹpởỉñťš',
      one: '1 ŵảỹpởỉñť',
      zero: 'Ñở ŵảỹpởỉñťš',
    );
    return '[$_temp0 ················]';
  }

  @override
  String get mapMyLocation => '[Mỹ łởçảťỉởñ ·····]';

  @override
  String get mapNoLocation =>
      '[Ñở łởçảťỉởñ ỹẽť - ŵảỉťỉñğ fởř ĞPŠ. ··············]';

  @override
  String get mapFollowHeading => '[Řởťảťẽ mảp ŵỉťh hẽảđỉñğ ··········]';

  @override
  String get mapNorthUp => '[Ñởřťh ữp ····]';

  @override
  String get mapOffline => '[Ởffłỉñẽ mảpš ·····]';

  @override
  String get mapOfflineIntro =>
      '[Đởŵñłởảđ mảp ảřẽảš ảhẽảđ ởf ťỉmẽ ťở ữšẽ ťhẽm ŵỉťhởữť ả çởññẽçťỉởñ: ảỉřpłảñẽ mởđẽ, mởữñťảỉñš, ảť šẽả. ········································]';

  @override
  String get mapOfflineOverview => '[Vỉẽťñảm ởvẽřvỉẽŵ ·······]';

  @override
  String get mapOfflineOverviewDesc =>
      '[Ťhẽ ŵhởłẽ çởữñťřỹ ỉñçłữđỉñğ ťhẽ Hởàñğ Šả ảñđ Ťřườñğ Šả ảřçhỉpẽłảğởš; mảỉñ řởảđš, přởvỉñçẽ ảñđ çỉťỹ ñảmẽš. ··········································]';

  @override
  String get mapOfflineCurrent => '[Çữřřẽñť vỉẽŵ ·····]';

  @override
  String mapOfflineCurrentDesc(int tiles) {
    return '[$tiles mảp ťỉłẽš, đẽťảỉłẽđ đởŵñ ťở šťřẽẽťš. ···············]';
  }

  @override
  String mapOfflineTooLarge(int tiles) {
    return '[Ťhỉš ảřẽả ỉš ťởở łảřğẽ ($tiles ťỉłẽš). Žởởm ỉñ ởñ ťhẽ mảp, ťhẽñ ťřỹ ảğảỉñ. ····························]';
  }

  @override
  String get mapOfflineNoView =>
      '[Ởpẽñ ťhẽ Mảp ťảb ảñđ mởvẽ ťở ťhẽ ảřẽả ỹởữ ŵảñť. ···················]';

  @override
  String get mapOfflineDownload => '[Đởŵñłởảđ ····]';

  @override
  String mapOfflineDownloading(int done, int total) {
    return '[Đởŵñłởảđỉñğ $done/$total ······]';
  }

  @override
  String get mapOfflineDone => '[Mảp ảřẽả đởŵñłởảđẽđ. ········]';

  @override
  String get mapOfflineFailed =>
      '[Đởŵñłởảđ đỉđñ\'ť fỉñỉšh - çhẽçk ỹởữř çởññẽçťỉởñ ảñđ ťřỹ ảğảỉñ. ·························]';

  @override
  String get mapOfflineSaved => '[Đởŵñłởảđẽđ ảřẽảš ·······]';

  @override
  String get mapOfflineEmpty => '[Ñở ảřẽảš ỹẽť. ······]';

  @override
  String get mapOfflineDelete => '[Đẽłẽťẽ ảřẽả ·····]';

  @override
  String mapOfflineDeleteTitle(String name) {
    return '[Đẽłẽťẽ \"$name\"? ····]';
  }

  @override
  String mapOfflineStorage(double mb) {
    final intl.NumberFormat mbNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String mbString = mbNumberFormat.format(mb);

    return '[Ữšỉñğ $mbString MB ởñ ťhỉš đẽvỉçẽ ··········]';
  }

  @override
  String mapOfflineAreaName(String date) {
    return '[Ảřẽả $date ··]';
  }

  @override
  String mapOfflineZoom(int from, int to) {
    return '[Đẽťảỉł łẽvẽłš $from-$to ······]';
  }

  @override
  String get arOpen => '[Vỉẽŵ hẽảđỉñğ ťhřởữğh çảmẽřả ···········]';

  @override
  String get arTitle => '[Çảmẽřả ẢŘ ····]';

  @override
  String get arPermission =>
      '[Çảmẽřả ảççẽšš łẽťš ťhẽ ảpp ởvẽřłảỹ hẽảđỉñğš ảñđ šảvẽđ pởỉñťš ởñ ťhẽ łỉvẽ vỉẽŵ. Ỉmảğẽš šťảỹ ởñ šçřẽẽñ ởñłỹ: ñởťhỉñğ ỉš çảpťữřẽđ, šťởřẽđ ởř šẽñť. ··························································]';

  @override
  String get arPermissionBlocked =>
      '[Çảmẽřả ảççẽšš ỉš ởff. Ťữřñ ỉť bảçk ởñ ỉñ ỹởữř đẽvỉçẽ Šẽťťỉñğš ťở ữšẽ Çảmẽřả ẢŘ. ································]';

  @override
  String get arGrant => '[Ảłłởŵ çảmẽřả ·····]';

  @override
  String get arOpenSettings => '[Ởpẽñ Šẽťťỉñğš ······]';

  @override
  String get arNoCamera =>
      '[Çởữłđñ\'ť ởpẽñ ťhẽ řẽảř çảmẽřả - ťhẽ đẽvỉçẽ hảš ñởñẽ ởř ảñởťhẽř ảpp ỉš ữšỉñğ ỉť. ································]';

  @override
  String get arRetry => '[Ťřỹ ảğảỉñ ····]';

  @override
  String get arHoldUpright =>
      '[Hởłđ ťhẽ phởñẽ ữpřỉğhť ŵỉťh ťhẽ çảmẽřả fảçỉñğ fởřŵảřđ. ······················]';

  @override
  String get arCalibrate =>
      '[Łởŵ çởmpảšš ảççữřảçỹ - çảłỉbřảťẽ ŵỉťh ả fỉğữřẽ 8. ····················]';

  @override
  String get arNoLocation =>
      '[Ñở łởçảťỉởñ ỹẽť - šảvẽđ pởỉñťš ảppẽảř ởñçẽ ĞPŠ ỉš řẽảđỹ. ·······················]';

  @override
  String arDistanceM(int value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '[$valueString m ··]';
  }

  @override
  String arDistanceKm(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '[$valueString km ··]';
  }

  @override
  String arHeadingLabel(int degrees) {
    return '[Çảmẽřả hẽảđỉñğ $degrees đẽğřẽẽš ··········]';
  }

  @override
  String get settingsPrivacy => '[Přỉvảçỹ ···]';

  @override
  String get noticeTitle => '[Ỹởữř đảťả ····]';

  @override
  String get noticeDevice =>
      '[Ŵảỹpởỉñťš, šẽťťỉñğš ảñđ ỹởữř łảšť łởçảťỉởñ ảřẽ šťởřẽđ ẽñçřỹpťẽđ ởñ ťhỉš đẽvỉçẽ ảñđ ñẽvẽř šẽñť ťở ởữř šẽřvẽřš. ············································]';

  @override
  String get noticeSensors =>
      '[Łởçảťỉởñ, çảmẽřả ảñđ šẽñšởřš ảřẽ přởçẽššẽđ ởñłỹ ởñ ťhỉš đẽvỉçẽ. Pẽřmỉššỉởñš ảřẽ ảškẽđ ởñłỹ ŵhẽñ ỹởữ ữšẽ ả fẽảťữřẽ ťhảť ñẽẽđš ťhẽm. ····················································]';

  @override
  String get noticeSecurity =>
      '[Ỉf ỹởữ ảğřẽẽ, ťhẽ ảpp šẽñđš ťẽçhñỉçảł šẽçữřỉťỹ đảťả ťở fỉğhť fřảữđ ảñđ ťảmpẽřẽđ çởpỉẽš: ả řảñđởm ỉñšťảłłảťỉởñ ỈĐ, đẽvỉçẽ mởđẽł, Ảñđřởỉđ ảñđ ảpp vẽřšỉởñ, Ğởởğłẽ\'š đẽvỉçẽ vẽřỉfỉçảťỉởñ řẽšữłť, ẽñvỉřởñmẽñť šỉğñảłš (řởởť, đẽbữğğẽř) ảñđ ỹởữř ỈP ảđđřẽšš. Ťhẽ fřẽẽŘẢŠP šẽçữřỉťỹ łỉbřảřỹ (Ťảłšẽç) šẽñđš šỉmỉłảř ẽñvỉřởñmẽñť ỉñfởřmảťỉởñ. ··································································································································]';

  @override
  String get noticeRetention =>
      '[Šẽçữřỉťỹ ẽvẽñťš ảřẽ kẽpť fởř 180 đảỹš ảñđ ỈP ảđđřẽššẽš ảřẽ ťřữñçảťẽđ ảfťẽř 90 đảỹš. Ŵẽ ñẽvẽř šẽłł đảťả ởř ữšẽ ťřảçkỉñğ ảđš. ··················································]';

  @override
  String get noticeRights =>
      '[Ỹởữ çảñ vỉẽŵ, ẽxpởřť ởř đẽłẽťẽ ỹởữř đảťả ảñđ ŵỉťhđřảŵ çởñšẽñť ảť ảñỹ ťỉmẽ ỉñ Šẽťťỉñğš > Přỉvảçỹ. ·······································]';

  @override
  String get noticePolicy => '[Řẽảđ ťhẽ fữłł přỉvảçỹ pởłỉçỹ ············]';

  @override
  String get consentAccept => '[Ảğřẽẽ ảñđ šťảřť ······]';

  @override
  String get consentOffline => '[Ữšẽ ởffłỉñẽ ởñłỹ ·······]';

  @override
  String get consentOfflineHint =>
      '[Ởffłỉñẽ: ťhẽ çởmpảšš, đởŵñłởảđẽđ mảpš ảñđ ŵảỹpởỉñťš šťỉłł ŵởřk fữłłỹ, bữť ỹởữ ŵởñ\'ť řẽçẽỉvẽ çởñfỉğữřảťỉởñ ởř šẽçữřỉťỹ ảłẽřťš fřởm ťhẽ šẽřvẽř. ·························································]';

  @override
  String get privacyOnline => '[Ởñłỉñẽ šẽçữřỉťỹ çởññẽçťỉởñ ···········]';

  @override
  String get privacyOnlineHint =>
      '[Šẽñđš ťẽçhñỉçảł šẽçữřỉťỹ đảťả ảñđ řẽçẽỉvẽš šỉğñẽđ çởñfỉğữřảťỉởñ. Ťữřñỉñğ ỉť ởff ŵỉťhđřảŵš çởñšẽñť; ťhẽ šẽçữřỉťỹ łỉbřảřỹ šťởpš çởmpłẽťẽłỹ fřởm ťhẽ ñẽxť ảpp łảữñçh. ·································································]';

  @override
  String get privacyCrash => '[Šẽñđ çřảšh řẽpởřťš ········]';

  @override
  String get privacyCrashHint =>
      '[Ŵhẽñ ťhẽ ảpp hỉťš ảñ ẽřřởř, šẽñđš ťhẽ ẽřřởř ťỹpẽ, ťhẽ ẽñçởđẽđ çởđẽ ťřảçẽ, ảñđ ťhẽ ảpp ảñđ Ảñđřởỉđ vẽřšỉởñš šở ŵẽ çảñ fỉx ỉť. Ñẽvẽř šẽñđš ỹởữř łởçảťỉởñ, ŵảỹpởỉñťš ởř ảñỹťhỉñğ ỹởữ ťỹpẽ; kẽpť fởř 90 đảỹš. ·················································································]';

  @override
  String get privacyCrashNeedsOnline =>
      '[Ťữřñ ởñ Ởñłỉñẽ šẽçữřỉťỹ çởññẽçťỉởñ fỉřšť. ·················]';

  @override
  String privacyChoiceAt(String date) {
    return '[Çhởỉçẽ řẽçởřđẽđ ởñ $date ········]';
  }

  @override
  String get privacyOnDevice => '[Đảťả ởñ ťhỉš đẽvỉçẽ ········]';

  @override
  String privacyWaypoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count šảvẽđ ŵảỹpởỉñťš',
      one: '1 šảvẽđ ŵảỹpởỉñť',
      zero: 'Ñở šảvẽđ ŵảỹpởỉñťš',
    );
    return '[$_temp0 ···················]';
  }

  @override
  String get privacyExport => '[Ẽxpởřť đảťả (JŠỞÑ) ········]';

  @override
  String get privacyExportDone => '[Đảťả fỉłẽ šảvẽđ ······]';

  @override
  String get privacyExportFailed => '[Đảťả fỉłẽ ñởť šảvẽđ ········]';

  @override
  String get privacyDeleteAll =>
      '[Đẽłẽťẽ ảłł đảťả ởñ ťhỉš đẽvỉçẽ ············]';

  @override
  String get privacyDeleteTitle => '[Đẽłẽťẽ ảłł đảťả? ·······]';

  @override
  String get privacyDeleteBody =>
      '[Ŵảỹpởỉñťš, ởffłỉñẽ mảpš, šẽťťỉñğš ảñđ đẽvỉçẽ kẽỹš ŵỉłł bẽ pẽřmảñẽñťłỹ đẽłẽťẽđ ảñđ ťhẽ ảpp ŵỉłł çłởšẽ. Ẽxpởřť ỹởữř đảťả fỉřšť ỉf ỹởữ ŵảñť ťở kẽẽp ỉť. ····························································]';

  @override
  String get privacyDeleteConfirm => '[Đẽłẽťẽ pẽřmảñẽñťłỹ ········]';

  @override
  String get privacyOnServer => '[Đảťả ởñ ởữř šẽřvẽřš ········]';

  @override
  String get privacyServerBody =>
      '[Ởữř šẽřvẽřš ởñłỹ kẽẽp ťẽçhñỉçảł šẽçữřỉťỹ đảťả łỉñkẽđ ťở ťhẽ đẽvỉçẽ ỈĐ bẽłởŵ, fởř ťhẽ pẽřỉởđš šťảťẽđ ỉñ ťhẽ pởłỉçỹ. ··············································]';

  @override
  String privacyDeviceId(String id) {
    return '[Đẽvỉçẽ ỈĐ: $id ·····]';
  }

  @override
  String get privacyNoDeviceId =>
      '[Ťhỉš đẽvỉçẽ ỉš ñởť řẽğỉšťẽřẽđ ŵỉťh ởữř šẽřvẽřš ···················]';

  @override
  String get privacyCopied => '[Đẽvỉçẽ ỈĐ çởpỉẽđ ·······]';

  @override
  String get privacyRequestDelete =>
      '[Řẽqữẽšť đẽłẽťỉởñ ởf šẽřvẽř đảťả ·············]';

  @override
  String get privacyRequestSubject =>
      '[Łả bàñ đảťả đẽłẽťỉởñ řẽqữẽšť ············]';

  @override
  String privacyRequestBody(String id) {
    return '[Đẽvỉçẽ ỈĐ: $id\nPłẽảšẽ đẽłẽťẽ ťhẽ đảťả łỉñkẽđ ťở ťhỉš đẽvỉçẽ.\n ························]';
  }

  @override
  String privacyMailFailed(String email) {
    return '[Çởữłđñ\'ť ởpẽñ ả mảỉł ảpp - płẽảšẽ ŵřỉťẽ ťở $email ··················]';
  }

  @override
  String get privacyPermissions => '[Šỹšťẽm pẽřmỉššỉởñš ········]';

  @override
  String get privacyPermissionsBody =>
      '[Łởçảťỉởñ ảñđ çảmẽřả ảřẽ mảñảğẽđ bỹ ťhẽ šỹšťẽm - řẽvởkẽ ťhẽm ảñỹ ťỉmẽ ỉñ ťhẽ ảpp šẽťťỉñğš. ····································]';

  @override
  String get privacyOpenSettings => '[Ởpẽñ ảpp šẽťťỉñğš ·······]';

  @override
  String get devModeBlockedTitle => '[Ťữřñ ởff đẽvẽłởpẽř mởđẽ ··········]';

  @override
  String get devModeBlockedBody =>
      '[Ťở přởťẽçť ỹởữř đảťả ảñđ ảççởữñť, Çởmpảšš đởẽšñ\'ť řữñ ŵhỉłẽ Đẽvẽłởpẽř ởpťỉởñš ởř ỮŠB / ŵỉřẽłẽšš đẽbữğğỉñğ ảřẽ ởñ. Ťữřñ ťhẽm ởff, ťhẽñ çởmẽ bảçk ťở ťhẽ ảpp. ······························································]';

  @override
  String get devModeStatusTitle => '[Çữřřẽñťłỹ ởñ ·····]';

  @override
  String get devModeItemOptions => '[Đẽvẽłởpẽř ởpťỉởñš ·······]';

  @override
  String get devModeItemUsb => '[ỮŠB đẽbữğğỉñğ ······]';

  @override
  String get devModeItemWifi => '[Ŵỉřẽłẽšš đẽbữğğỉñğ ········]';

  @override
  String get devModeHowTo =>
      '[Šẽťťỉñğš > Šỹšťẽm (ởř Ảđđỉťỉởñảł šẽťťỉñğš) > Đẽvẽłởpẽř ởpťỉởñš > šŵỉťçh ťhẽ ťởp ťởğğłẽ ởff. ·····································]';

  @override
  String get devModeOpenSettings => '[Ởpẽñ Đẽvẽłởpẽř ởpťỉởñš ·········]';

  @override
  String get devModeOpenFailed =>
      '[Çởữłđñ\'ť ởpẽñ šẽťťỉñğš - ởpẽñ ỹởữř phởñẽ\'š Šẽťťỉñğš ảpp. ·······················]';

  @override
  String get devModeRecheck => '[Çhẽçk ảğảỉñ ·····]';

  @override
  String get devModeServerOnly =>
      '[Ťhẽ šẽřvẽř šťỉłł šẽẽš đẽvẽłởpẽř mởđẽ - çởññẽçť ťở ťhẽ ỉñťẽřñẽť, ťhẽñ ťảp Çhẽçk ảğảỉñ. ··································]';

  @override
  String get m1ProTitle => '[Çởmpảšš Přở ·····]';

  @override
  String get m1ProTagline =>
      '[Řẽmởvẽ ảđš ảñđ hẽłp Çởmpảšš kẽẽp ğřởŵỉñğ. ·················]';

  @override
  String get m1BenefitNoAds => '[Ñở ảđš ởñ ảñỹ šçřẽẽñ ········]';

  @override
  String get m1BenefitFree =>
      '[Fřẽẽ fẽảťữřẽš šťảỹ fřẽẽ: çởmpảšš, çởởřđỉñảťẽš, ŵảỹpởỉñťš, šhảřỉñğ, ởffłỉñẽ mảpš, ẢŘ çảmẽřả ····································]';

  @override
  String get m1BenefitNew =>
      '[Ğẽť ñẽŵ Přở fẽảťữřẽš ảš šởởñ ảš ťhẽỹ łảữñçh ··················]';

  @override
  String get m1BenefitSupport =>
      '[Šữppởřť ảñ ỉñđẽpẽñđẽñť đẽvẽłởpẽř ·············]';

  @override
  String get m1PlanYear => '[Ỹẽảřłỹ ···]';

  @override
  String get m1PlanMonth => '[Mởñťhłỹ ···]';

  @override
  String get m1PlanLifetime => '[Łỉfẽťỉmẽ ····]';

  @override
  String m1PricePerYear(String price) {
    return '[$price / ỹẽảř ···]';
  }

  @override
  String m1PricePerMonth(String price) {
    return '[$price / mởñťh ····]';
  }

  @override
  String m1PriceOnce(String price) {
    return '[$price - ởñẽ-ťỉmẽ pảỹmẽñť ········]';
  }

  @override
  String m1TrialBadge(int days) {
    return '[$days-đảỹ fřẽẽ ťřỉảł ······]';
  }

  @override
  String get m1Continue => '[Çởñťỉñữẽ ····]';

  @override
  String get m1StartTrial => '[Šťảřť fřẽẽ ťřỉảł ·······]';

  @override
  String get m1Restore => '[Řẽšťởřẽ pữřçhảšẽš ·······]';

  @override
  String get m1Manage => '[Mảñảğẽ šữbšçřỉpťỉởñ ởñ Ğởởğłẽ Płảỹ ··············]';

  @override
  String get m1ManageFailed =>
      '[Çởữłđñ\'ť ởpẽñ Ğởởğłẽ Płảỹ ởñ ťhỉš đẽvỉçẽ. ·················]';

  @override
  String m1TermsSub(String price) {
    return '[Ťhẽ šữbšçřỉpťỉởñ řẽñẽŵš ảữťởmảťỉçảłłỹ ảť $price ữñťỉł ỹởữ çảñçẽł. Çảñçẽł ảñỹťỉmẽ ỉñ Ğởởğłẽ Płảỹ > Pảỹmẽñťš & šữbšçřỉpťỉởñš, ảť łẽảšť 24 hởữřš bẽfởřẽ ťhẽ çữřřẽñť pẽřỉởđ ẽñđš ťở ảvởỉđ bẽỉñğ çhảřğẽđ fởř ťhẽ ñẽxť ởñẽ. Pảỹmẽñť ỉš çhảřğẽđ ťở ỹởữř Ğởởğłẽ Płảỹ ảççởữñť ŵhẽñ ỹởữ çởñfỉřm ťhẽ pữřçhảšẽ. ··················································································································]';
  }

  @override
  String m1TermsTrial(int days, String price) {
    return '[Ảfťẽř ťhẽ $days-đảỹ ťřỉảł ỹởữ ŵỉłł bẽ çhảřğẽđ $price ữñłẽšš ỹởữ çảñçẽł bẽfởřẽ ťhẽ ťřỉảł ẽñđš. ·································]';
  }

  @override
  String get m1TermsLifetime =>
      '[Ởñẽ-ťỉmẽ pảỹmẽñť, ñở ảữťở-řẽñẽŵảł. Ữšẽ ỉť ởñ ảñỹ đẽvỉçẽ šỉğñẽđ ỉñ ťở ťhẽ šảmẽ Ğởởğłẽ ảççởữñť (Řẽšťởřẽ pữřçhảšẽš). ··············································]';

  @override
  String get m1Loading => '[Łởảđỉñğ płảñš fřởm Ğởởğłẽ Płảỹ… ·············]';

  @override
  String get m1Unavailable =>
      '[Ğởởğłẽ Płảỹ ỉšñ\'ť ảvảỉłảbłẽ ởñ ťhỉš đẽvỉçẽ ởř ťhẽ płảñš ảřẽñ\'ť ởñ šảłẽ ỹẽť. Płẽảšẽ ťřỹ ảğảỉñ łảťẽř. ········································]';

  @override
  String get m1Retry => '[Ťřỹ ảğảỉñ ····]';

  @override
  String get m1Pending =>
      '[Ğởởğłẽ Płảỹ ỉš ŵảỉťỉñğ fởř ỹởữ ťở çởmpłẽťẽ pảỹmẽñť. Çởmpảšš Přở ťữřñš ởñ ởñçẽ pảỹmẽñť ğởẽš ťhřởữğh. ········································]';

  @override
  String get m1Verifying => '[Çởñfỉřmỉñğ ỹởữř pữřçhảšẽ… ··········]';

  @override
  String get m1Success => '[Ťhảñk ỹởữ! Çởmpảšš Přở ỉš ñởŵ ởñ. ··············]';

  @override
  String get m1Active => '[Ỹởữ\'řẽ ữšỉñğ Çởmpảšš Přở ··········]';

  @override
  String m1ActiveUntil(String date) {
    return '[Vảłỉđ ữñťỉł $date ·····]';
  }

  @override
  String get m1ActiveLifetime => '[Łỉfẽťỉmẽ płảñ ······]';

  @override
  String get m1Grace =>
      '[Çởñfỉřmỉñğ ỹởữř řẽñẽŵảł ŵỉťh Ğởởğłẽ Płảỹ - Přở šťảỹš ởñ mẽảñŵhỉłẽ. ···························]';

  @override
  String get m1ErrNetwork =>
      '[Çởữłđñ\'ť řẽảçh ťhẽ šẽřvẽř. Ỹởữř pữřçhảšẽ ỉš kẽpť ảñđ ŵỉłł bẽ çởñfỉřmẽđ ảữťởmảťỉçảłłỹ ŵhẽñ ỹởữ\'řẽ ởñłỉñẽ. ··········································]';

  @override
  String get m1ErrStore =>
      '[Ğởởğłẽ Płảỹ çởữłđñ\'ť šťảřť ťhẽ pữřçhảšẽ. Płẽảšẽ ťřỹ ảğảỉñ. ························]';

  @override
  String get m1ErrToken =>
      '[Ťhẽ pữřçhảšẽ çởữłđñ\'ť bẽ vẽřỉfỉẽđ ŵỉťh Ğởởğłẽ Płảỹ. Ỉf ỹởữ ŵẽřẽ çhảřğẽđ, Ğởởğłẽ řẽfữñđš ỉť ảữťởmảťỉçảłłỹ ŵỉťhỉñ 3 đảỹš. ················································]';

  @override
  String get m1ErrShared =>
      '[Ťhỉš pữřçhảšẽ ỉš ỉñ ữšẽ ởñ ťởở mảñỹ đẽvỉçẽš. Ỉf ťhỉš ỉš ả mỉšťảkẽ, šẽñđ ảñ ảppẽảł ŵỉťh ỹởữř đẽvỉçẽ çởđẽ. ··········································]';

  @override
  String get m1ErrNotPlay =>
      '[Ťhỉš çởpỹ ŵảšñ\'ť ỉñšťảłłẽđ fřởm Ğởởğłẽ Płảỹ, šở ỉť çảñ\'ť řẽçẽỉvẽ Přở. Ỉñšťảłł Çởmpảšš fřởm Ğởởğłẽ Płảỹ, ťhẽñ ťảp Řẽšťởřẽ pữřçhảšẽš. ·····················································]';

  @override
  String get m1ErrServer =>
      '[Ťhẽ šẽřvẽř çởữłđñ\'ť çởñfỉřm ťhẽ pữřçhảšẽ ỹẽť. Płẽảšẽ ťřỹ ảğảỉñ ỉñ ả fẽŵ mỉñữťẽš. ································]';

  @override
  String get m1ErrNothing =>
      '[Ñở pữřçhảšẽš fởữñđ fởř ťhẽ Ğởởğłẽ ảççởữñť šỉğñẽđ ỉñ ťở Płảỹ. ························]';

  @override
  String get m1Dismiss => '[Đỉšmỉšš ···]';

  @override
  String get m1SettingsSubFree =>
      '[Řẽmởvẽ ảđš, šữppởřť đẽvẽłởpmẽñť ·············]';

  @override
  String get m1SettingsSubPro => '[Ảçťỉvẽ ···]';

  @override
  String get a9FieldNormal =>
      '[Fỉẽłđ ñởřmảł - ñở mảğñẽťỉç ỉñťẽřfẽřẽñçẽ ñẽảřbỹ. ···················]';

  @override
  String get a9SrcCompass => '[Çởmpảšš (mảğñẽťởmẽťẽř) ·········]';

  @override
  String get a9SrcGps => '[ĞPŠ çởữřšẽ ····]';

  @override
  String get a9SrcSun => '[Šữñ ··]';

  @override
  String get a9SrcMoon => '[Mởởñ ··]';

  @override
  String get a9SrcManual => '[Šẽť bỹ hảñđ ·····]';

  @override
  String a9SrcWithGyro(String nguon) {
    return '[$nguon + ğỹřở ···]';
  }

  @override
  String a9SrcLine(String nguon, int saiSo) {
    return '[Šởữřçẽ: $nguon · ±$saiSo° ······]';
  }

  @override
  String get a9NoMagTitle =>
      '[Ťhỉš phởñẽ hảš ñở mảğñẽťỉç çởmpảšš ··············]';

  @override
  String get a9NoMagBody =>
      '[Ỹởữ çảñ šťỉłł ğẽť ả đỉřẽçťỉởñ: ŵảłk ả fẽŵ šťẽpš ťở ữšẽ ťhẽ ĞPŠ çởữřšẽ, ởř šẽť ỉť fřởm ťhẽ Šữñ, ťhẽ Mởởñ ởř ả łảñđmảřk ŵhởšẽ đỉřẽçťỉởñ ỹởữ kñởŵ. ··························································]';

  @override
  String get a9BtnSun => '[Ữšẽ ťhẽ Šữñ\'š šhảđởŵ ········]';

  @override
  String get a9BtnMoon => '[Pởỉñť ảť ťhẽ Mởởñ ·······]';

  @override
  String get a9BtnManual => '[Šẽť đỉřẽçťỉởñ bỹ hảñđ ·········]';

  @override
  String get a9BtnDevice => '[Ỹởữř đẽvỉçẽ ·····]';

  @override
  String get a9BtnSet => '[Šẽť đỉřẽçťỉởñ ······]';

  @override
  String get a9SunHelp =>
      '[Šťảñđ šởmẽťhỉñğ ữpřỉğhť (ả pẽñ, ả šťỉçk). Łảỹ ťhẽ phởñẽ fłảť ảłởñğ ỉťš šhảđởŵ, ťởp ẽđğẽ pởỉñťỉñğ ảŵảỹ fřởm ťhẽ ởbjẽçť, ťhẽñ ťảp Šẽť đỉřẽçťỉởñ. Ñẽvẽř łởởk šťřảỉğhť ảť ťhẽ Šữñ. ······································································]';

  @override
  String get a9MoonHelp =>
      '[Pởỉñť ťhẽ ťởp ẽđğẽ ởf ťhẽ phởñẽ šťřảỉğhť ảť ťhẽ Mởởñ, ťhẽñ ťảp Šẽť đỉřẽçťỉởñ. ·······························]';

  @override
  String get a9ManualHelp =>
      '[Pởỉñť ťhẽ ťởp ẽđğẽ ởf ťhẽ phởñẽ ảť ả łảñđmảřk ŵhởšẽ đỉřẽçťỉởñ ỹởữ kñởŵ (ẽ.ğ. ả řởảđ řữññỉñğ ñởřťh), đřảğ ťở ťhảť bẽảřỉñğ, ťhẽñ ťảp Šẽť đỉřẽçťỉởñ. ··························································]';

  @override
  String get a9SkyLow =>
      '[Ťhẽ Šữñ ảñđ Mởởñ ảřẽ bẽłởŵ ťhẽ hởřỉžởñ ởř ỹởữř łởçảťỉởñ ỉš ữñkñởŵñ - ữšẽ ĞPŠ ởř šẽť ťhẽ đỉřẽçťỉởñ bỹ hảñđ. ···········································]';

  @override
  String get a9SetFailed =>
      '[Çởữłđñ\'ť šẽť ỉť: ťhẽ Šữñ ởř Mởởñ ỉš ťởở łởŵ ñởŵ. ····················]';

  @override
  String get a9Reanchor =>
      '[Ỉť\'š bẽẽñ ả ŵhỉłẽ - ťhẽ đỉřẽçťỉởñ mảỹ hảvẽ đřỉfťẽđ. Šẽť ỉť ảğảỉñ. ··························]';

  @override
  String get a9StaticAnchor =>
      '[Ñở ğỹřởšçởpẽ: kẽẽp ťhẽ phởñẽ ẽxảçťłỹ ảš ảłỉğñẽđ; šẽť ỉť ảğảỉñ ảfťẽř ťữřñỉñğ. ·······························]';

  @override
  String get a9Walking =>
      '[Ŵảłkỉñğ: ťhẽ ĞPŠ çởữřšẽ ỉš ữšẽđ ảữťởmảťỉçảłłỹ. ···················]';

  @override
  String get a9DeviceTitle => '[Ỹởữř đẽvỉçẽ ·····]';

  @override
  String get a9DeviceIntro =>
      '[Ťhẽ ảpp çhẽçkš ởñçẽ ŵhỉçh šẽñšởřš ťhỉš phởñẽ hảš (ỹẽš / ñở ởñłỹ, ñở đẽvỉçẽ ỈĐš) ťở pỉçk ťhẽ bẽšť ŵảỹ ťở fỉñđ ả đỉřẽçťỉởñ. ·················································]';

  @override
  String get a9DeviceProbing => '[Çhẽçkỉñğ šẽñšởřš… ·······]';

  @override
  String get a9SensMag => '[Mảğñẽťởmẽťẽř (çởmpảšš) ·········]';

  @override
  String get a9SensGyro => '[Ğỹřởšçởpẽ ····]';

  @override
  String get a9SensAccel => '[Ảççẽłẽřởmẽťẽř ······]';

  @override
  String get a9SensGameRot => '[Šỹšťẽm řởťảťỉởñ fữšỉởñ ·········]';

  @override
  String get a9SensBaro => '[Bảřởmẽťẽř (ảłťỉťữđẽ) ········]';

  @override
  String get a9SensGps => '[ĞPŠ ··]';

  @override
  String get a9SensCamera => '[Řẽảř çảmẽřả ·····]';

  @override
  String get a9Yes => '[Ỹẽš ··]';

  @override
  String get a9No => '[Ñở ··]';

  @override
  String get a9SourcesTitle =>
      '[Đỉřẽçťỉởñ šởữřçẽš ảvảỉłảbłẽ (ỉñ přỉởřỉťỹ ởřđẽř) ···················]';

  @override
  String get a9LiteOn =>
      '[Łỉťẽ mởđẽ ỉš ởñ: ťhẽ đỉảł škỉpš šmởởťh řởťảťỉởñ šở ťhẽ phởñẽ šťảỹš řẽšpởñšỉvẽ. ································]';

  @override
  String get a9LiteOff =>
      '[Łỉťẽ mởđẽ: ởff - ťhỉš phởñẽ hảñđłẽš ťhẽ fữłł ẽffẽçťš. ······················]';

  @override
  String get appTitlePro => '[Çởmpảšš Přở ·····]';

  @override
  String get m2LicenseTitle => '[Çởmpảšš Přở łỉçẽñšẽ ········]';

  @override
  String get m2LicenseOk =>
      '[Vẽřỉfỉẽđ bỹ Ğởởğłẽ Płảỹ - ảłł Přở fẽảťữřẽš ữñłởçkẽđ ·····················]';

  @override
  String get m2LicenseMissing =>
      '[Ñởť vẽřỉfỉẽđ - ťảp ťở ğẽť ťhẽ ởffỉçỉảł çởpỹ fřởm Ğởởğłẽ Płảỹ ························]';

  @override
  String get m2LicenseFixFail =>
      '[Çởữłđñ\'ť ởpẽñ Ğởởğłẽ Płảỹ. Ỉñšťảłł Çởmpảšš Přở fřởm Ğởởğłẽ Płảỹ, ťhẽñ řẽởpẽñ ťhẽ ảpp. ··································]';

  @override
  String get m2LicenseFixDone => '[Łỉçẽñšẽ řẽ-çhẽçk řẽqữẽšťẽđ. ···········]';

  @override
  String get m2bMoveTitle => '[Mởvẽ ťở Çởmpảšš Přở ········]';

  @override
  String get m2bMoveSubtitle =>
      '[Çởmpảšš Přở ỉš ỉñšťảłłẽđ - šẽñđ ŵảỹpởỉñťš, phởťởš ảñđ šẽťťỉñğš ťở ỉť ····························]';

  @override
  String get m2bMoveIntro =>
      '[Šẽñđ ỹởữř ŵảỹpởỉñťš (ŵỉťh phởťởš), ỹởữř ởffłỉñẽ mảp ảřẽảš ảñđ ỹởữř đỉšpłảỹ çhởỉçẽš ťở Çởmpảšš Přở ởñ ťhỉš đẽvỉçẽ. Đảťả ğởẽš šťřảỉğhť fřởm ảpp ťở ảpp, ñẽvẽř ởvẽř ťhẽ ñẽťŵởřk; ťhỉš ảpp kẽẽpš ỉťš ởŵñ çởpỹ. ·················································································]';

  @override
  String m2bMoveCounts(int points, int photos, int areas) {
    return '[$points ŵảỹpởỉñťš · $photos phởťởš · $areas ởffłỉñẽ ảřẽảš ···············]';
  }

  @override
  String get m2bMoveSend => '[Šẽñđ ťở Çởmpảšš Přở ········]';

  @override
  String get m2bMoveOpenPro => '[Ởpẽñ Çởmpảšš Přở ·······]';

  @override
  String get m2bMoveNotInstalled =>
      '[Ởffỉçỉảł Çởmpảšš Přở fřởm Ğởởğłẽ Płảỹ ỉš ñởť ỉñšťảłłẽđ ởñ ťhỉš đẽvỉçẽ. ····························]';

  @override
  String get m2bMoveGetPro => '[Šẽẽ Çởmpảšš Přở ởñ Ğởởğłẽ Płảỹ ············]';

  @override
  String get m2bMoveFailed =>
      '[Çởữłđ ñởť šẽñđ. Ữšẽ Šẽťťỉñğš > Přỉvảçỹ > Ẽxpởřť đảťả, ťhẽñ pỉçk ťhảť fỉłẽ ỉñ Çởmpảšš Přở. ····································]';

  @override
  String get m2bImportTitle => '[Ỉmpởřť fřởm Çởmpảšš ········]';

  @override
  String get m2bImportSubtitle =>
      '[Břỉñğ ŵảỹpởỉñťš, phởťởš ảñđ šẽťťỉñğš fřởm ťhẽ fřẽẽ ảpp ······················]';

  @override
  String get m2bImportIntro =>
      '[Ťảkẽ ỹởữř đảťả fřởm Çởmpảšš (fřẽẽ ảpp) ởñ ťhỉš đẽvỉçẽ, ởř pỉçk ả fỉłẽ šảvẽđ ŵỉťh Šẽťťỉñğš > Přỉvảçỹ > Ẽxpởřť đảťả. Ỹởữ řẽvỉẽŵ ẽvẽřỹťhỉñğ bẽfởřẽ ỉť ỉš ỉmpởřťẽđ. ································································]';

  @override
  String get m2bImportFromFree =>
      '[Ťảkẽ fřởm Çởmpảšš ởñ ťhỉš đẽvỉçẽ ·············]';

  @override
  String get m2bImportFreeMissing =>
      '[Ťhẽ ởffỉçỉảł fřẽẽ Çởmpảšš ảpp ỉš ñởť ởñ ťhỉš đẽvỉçẽ - pỉçk ảñ ẽxpởřť fỉłẽ ỉñšťẽảđ. ·································]';

  @override
  String get m2bImportFile => '[Pỉçk ảñ ẽxpởřť fỉłẽ ········]';

  @override
  String get m2bImportConfirmTitle => '[Řẽvỉẽŵ bẽfởřẽ ỉmpởřťỉñğ ··········]';

  @override
  String m2bImportPlan(int added, int updated, int same) {
    return '[$added ñẽŵ · $updated ữpđảťẽđ · $same ảłřẽảđỹ hẽřẽ ·············]';
  }

  @override
  String m2bImportPhotos(int count) {
    return '[$count phởťởš ŵỉťh ťhẽ ñẽŵ ŵảỹpởỉñťš ············]';
  }

  @override
  String get m2bImportSettings =>
      '[Ữšẽ ťhẽ łảñğữảğẽ, ťhẽmẽ ảñđ çởmpảšš ởpťỉởñš ởf ťhẽ fřẽẽ ảpp ························]';

  @override
  String m2bImportSkipped(int count) {
    return '[$count břởkẽñ ỉťẽmš ŵỉłł bẽ škỉppẽđ ············]';
  }

  @override
  String get m2bImportDo => '[Ỉmpởřť ···]';

  @override
  String m2bImportDone(int added, int updated) {
    return '[Ỉmpởřťẽđ $added ñẽŵ ảñđ ữpđảťẽđ $updated ŵảỹpởỉñťš. ···············]';
  }

  @override
  String get m2bImportBadFile =>
      '[Ťhỉš fỉłẽ ỉš ñởť vảłỉđ Çởmpảšš đảťả. ···············]';

  @override
  String get m2bImportEmpty => '[Ñởťhỉñğ ťở ỉmpởřť. ········]';

  @override
  String get m2bImportNoPhotos =>
      '[Ả pẽřšởñảł đảťả ẽxpởřť hảš ñở phởťởš ởř mảp ảřẽảš - ởñłỹ ŵảỹpởỉñťš ảñđ šẽťťỉñğš ảřẽ ỉmpởřťẽđ. ······································]';

  @override
  String get m2bAreasTitle => '[Đởŵñłởảđ ởffłỉñẽ ảřẽảš ảğảỉñ ············]';

  @override
  String get m2bAreasIntro =>
      '[Đởŵñłởảđẽđ mảpš šťảỹ ỉñšỉđẽ ẽảçh ảpp, šở Çởmpảšš Přở ñẽẽđš ťở đởŵñłởảđ ťhẽm ảğảỉñ (ñẽťŵởřk ñẽẽđẽđ). ········································]';

  @override
  String get m2bAreaDone => '[Đởŵñłởảđẽđ ····]';
}
