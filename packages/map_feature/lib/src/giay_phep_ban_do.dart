import 'package:flutter/foundation.dart';

/// Ghi công dữ liệu + thành phần native của bản đồ (A7b) trên màn Giấy phép.
/// Thư viện Dart (maplibre_gl) tự có từ LICENSE của gói; phần dưới đây không.
void dangKyGiayPhepBanDo() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Map data: OpenStreetMap (ODbL), Protomaps basemap'],
      'Map tiles contain data © OpenStreetMap contributors, available under '
      'the Open Database License (ODbL) 1.0: '
      'https://www.openstreetmap.org/copyright\n\n'
      'Vector tile schema: Protomaps basemaps (BSD-3-Clause), '
      'https://github.com/protomaps/basemaps',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Noto Sans (map labels)'],
      'Copyright 2022 The Noto Project Authors '
      '(https://github.com/notofonts). Licensed under the SIL Open Font '
      'License, Version 1.1: https://openfontlicense.org',
    );
    yield const LicenseEntryWithLineBreaks(
      ['MapLibre Native'],
      'Copyright (c) 2021 MapLibre contributors; Copyright (c) 2018-2021 '
      'MapTiler.com; Copyright (c) 2014-2020 Mapbox. Licensed under the '
      'BSD 2-Clause License: '
      'https://github.com/maplibre/maplibre-native/blob/main/LICENSE.md',
    );
  });
}
