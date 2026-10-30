import 'package:compass_feature/compass_feature.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/app.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:map_feature/map_feature.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:test_kit/test_kit.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// Lựa chọn thông báo dữ liệu đã trả lời (bản hiện hành, ngoại tuyến - test
/// không mạng).
final dongYThu = DongYXuLy(
  ban: banThongBaoDuLieu,
  trucTuyen: false,
  luc: DateTime.utc(2026, 10, 30),
);

/// `cai_dat.json` đã qua màn giới thiệu + trả lời thông báo dữ liệu.
Map<String, Object?> caiDatDaXemJson([Map<String, Object?> them = const {}]) =>
    {'daXemGioiThieu': true, 'dongY': dongYThu.toJson(), ...them};

/// Cài đặt ban đầu đã qua màn giới thiệu.
class CaiDatDaXem extends CaiDatNotifier {
  @override
  CaiDat build() => CaiDat(daXemGioiThieu: true, dongY: dongYThu);
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

/// Ghi đè chung của test app: hướng cố định + bản đồ phẳng (platform view
/// MapLibre không chạy trong test widget).
final List<Override> ghiDeThu = [
  huongThu,
  banDoThatProvider.overrideWithValue(false),
];

/// App đầy đủ trong ProviderScope mới (kho điểm trong bộ nhớ trừ khi
/// [khoDiem] = false).
Widget appThu({
  bool daXem = true,
  bool khoDiem = true,
  List<Override> them = const [],
}) => ProviderScope(
  overrides: [
    if (daXem) caiDatProvider.overrideWith(CaiDatDaXem.new),
    if (khoDiem) khoDiemProvider.overrideWithValue(KhoDiemBoNho()),
    ...ghiDeThu,
    ...them,
  ],
  child: const LaBanApp(flavor: Flavor.dev),
);
