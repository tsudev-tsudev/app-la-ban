import 'package:compass_feature/compass_feature.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/app.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:test_kit/test_kit.dart';

/// Cài đặt ban đầu đã qua màn giới thiệu.
class CaiDatDaXem extends CaiDatNotifier {
  @override
  CaiDat build() => const CaiDat(daXemGioiThieu: true);
}

/// Đặt ngôn ngữ / sáng tối / cỡ chữ của HỆ THỐNG theo ô [o] (app để "Theo
/// hệ thống" nên đi đúng đường thật).
void datHeThong(WidgetTester tester, OMaTran o) {
  tester.platformDispatcher
    ..localesTestValue = [o.ngonNgu]
    ..platformBrightnessTestValue = o.sang
    ..textScaleFactorTestValue = o.coChu;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Hướng cố định thay cảm biến thật (test không có plugin nền tảng).
final Override huongThu = huongProvider.overrideWith(
  (ref) => Stream.value(
    const HuongDoc(
      phuongVi: 42,
      phuongViTho: 42,
      doc: 0,
      lan: 0,
      theoCamera: false,
      muc: MucTinCay.cao,
      nhieuTu: false,
      canHieuChuan: false,
      cuongDoTu: 45,
      nguon: NguonHuong.madgwick,
      dungYen: false,
      tNs: 0,
    ),
  ),
);

/// App đầy đủ trong ProviderScope mới.
Widget appThu({bool daXem = true, List<Override> them = const []}) =>
    ProviderScope(
      overrides: [
        if (daXem) caiDatProvider.overrideWith(CaiDatDaXem.new),
        huongThu,
        ...them,
      ],
      child: const LaBanApp(flavor: Flavor.dev),
    );
