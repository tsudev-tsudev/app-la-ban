// Ảnh chụp màn hình cho Google Play (R2): sinh lại bằng
// `./tools/build/anh-store.sh` (= flutter test test_store --update-goldens).
// Nằm ngoài test/ nên cổng không chạy; ảnh ra design/store/play/<vi|en>/.
// `./tools/build/anh-store.sh --pro` (M2b, --dart-define=PRO=true): dựng app
// La bàn Pro, ảnh ra design/store/pro/<vi|en>/.
import 'dart:io';

import 'package:app_shell/src/app.dart';
import 'package:app_shell/src/diem.dart';
import 'package:app_shell/src/flavor.dart';
import 'package:app_shell/src/pro.dart';
import 'package:compass_feature/compass_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:location_feature/location_feature.dart';
import 'package:quyen_loi/quyen_loi.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:test_kit/test_kit.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

import '../test/ho_tro.dart';

/// 1080 x 1920 px (9:16, Play khuyên dùng) ở mật độ 2,625 như máy 1080p.
const _px = Size(1080, 1920);
const _dpr = 2.625;

/// Cờ `--dart-define=PRO=true`: ảnh cho listing La bàn Pro (M2b bước 4).
const _pro = bool.fromEnvironment('PRO');

const _cauHinh = CauHinhSanPham(
  flavor: Flavor.prod,
  loai: _pro ? LoaiApp.pro : LoaiApp.mienPhi,
  phienBan: '0.1.0+1',
);

const _gocPhut = 1793437200000; // 31/10/2026 09:00 UTC, ms

List<DiemMoc> _diem(Locale l) {
  final vi = l.languageCode == 'vi';
  DiemMoc d(
    String id,
    String ten,
    double viDo,
    double kinhDo,
    double cao,
    String ghiChu,
    int phut,
  ) => DiemMoc(
    id: id,
    ten: ten,
    viDo: viDo,
    kinhDo: kinhDo,
    caoDo: cao,
    ghiChu: ghiChu,
    taoLuc: _gocPhut - phut * 60000,
    suaLuc: _gocPhut - phut * 60000,
  );
  return [
    d(
      '1',
      vi ? 'Đỉnh Fansipan' : 'Fansipan summit',
      22.3033,
      103.7750,
      3143,
      vi ? 'Cột mốc inox trên đỉnh' : 'Steel marker at the top',
      10,
    ),
    d(
      '2',
      vi ? 'Trạm Tôn' : 'Tram Ton pass',
      22.3473,
      103.7744,
      1900,
      vi ? 'Điểm xuất phát' : 'Trailhead',
      300,
    ),
    d(
      '3',
      vi ? 'Bãi trại 2800' : 'Camp 2800',
      22.3098,
      103.7801,
      2800,
      vi ? 'Nguồn nước bên phải' : 'Water on the right',
      600,
    ),
    d(
      '4',
      vi ? 'Hồ Gươm' : 'Hoan Kiem Lake',
      21.0285,
      105.8522,
      12,
      vi ? 'Cổng đền Ngọc Sơn' : 'Ngoc Son temple gate',
      9000,
    ),
  ];
}

/// Vị trí cố định gần Trạm Tôn để màn dẫn đường có khoảng cách / hướng thật.
final Override _viTri = nguonViTriProvider.overrideWithValue(
  NguonViTriGhiSan([
    DocViTri(
      viDo: 22.3401,
      kinhDo: 103.7702,
      luc: DateTime.utc(2026, 10, 31),
      doCaoMucBien: 1950,
      doChinhXacNgang: 4,
    ),
  ]),
);

Widget _app(Locale l) => ProviderScope(
  overrides: [
    caiDatProvider.overrideWith(CaiDatDaXem.new),
    khoDiemProvider.overrideWithValue(KhoDiemBoNho(_diem(l))),
    ...ghiDeThu,
    _viTri,
    // Như noiDiem của app: tab Điểm đọc vị trí qua location_feature.
    viTriDiemProvider.overrideWith(viTriChoDiem),
    // Như dungApp: mục Cài đặt chọn theo loại app (Pro -> Bản quyền).
    cauHinhSanPhamProvider.overrideWithValue(_cauHinh),
    // App Pro cài từ Play: máy chủ đã cấp `pro_app` (vĩnh viễn).
    if (_pro)
      trangThaiQuyenLoiProvider.overrideWithValue(
        const TrangThaiQuyenLoi(
          MucQuyenLoi.pro,
          QuyenLoi(pro: true, khongQuangCao: true),
        ),
      ),
  ],
  child: const LaBanApp(cauHinh: _cauHinh),
);

/// Icon Material (nút quay lại của AppBar) - flutter_test không nạp sẵn.
Future<void> _napIconMaterial() async {
  final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent;
  final tep = File(
    '${sdk.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(tep.readAsBytesSync())))).load();
}

void main() {
  setUpAll(() async {
    await napFontThat();
    await _napIconMaterial();
  });

  for (final l in [LbNgonNgu.vi, LbNgonNgu.en]) {
    for (final s in Brightness.values) {
      testWidgets('ảnh store ${l.languageCode} ${s.name}', (tester) async {
        tester.view
          ..physicalSize = _px
          ..devicePixelRatio = _dpr;
        addTearDown(tester.view.reset);
        datHeThong(tester, (
          manHinh: (ten: 'store', kichCo: _px / _dpr),
          sang: s,
          ngonNgu: l,
          coChu: 1,
        ));
        // Ảnh như trên điện thoại cảm ứng: không vẽ viền focus bàn phím.
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );
        await tester.pumpWidget(_app(l));
        await tester.pump(const Duration(seconds: 2));

        final dir =
            '../../../design/store/${_pro ? 'pro' : 'play'}/${l.languageCode}';
        var so = 0;
        // pump(d) chỉ dựng MỘT khung -> bơm nhiều khung để luồng dữ liệu /
        // chuyển trang kịp vẽ (mặt la bàn có hoạt ảnh nên không pumpAndSettle).
        Future<void> doi() async {
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        Future<void> chup(String ten) async {
          await doi();
          so++;
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('$dir/${s.name}-$so-$ten.png'),
          );
        }

        final daMo = <NavigatorState>[];
        Future<void> moi(Widget man) async {
          final nav = Navigator.of(tester.element(find.byType(Scaffold).last));
          daMo.add(nav);
          nav.push(MaterialPageRoute<void>(builder: (_) => man));
          await doi();
        }

        Future<void> ve() async {
          daMo.removeLast().pop();
          await doi();
        }

        await chup('la-ban');
        await moi(const ManHieuChuan());
        await chup('hieu-chuan');
        await ve();

        await tester.tap(find.byKey(const ValueKey('tab/diem')));
        await chup('diem');
        final dau = _diem(l).first;
        await moi(ManChiTietDiem(id: dau.id));
        await chup('chi-tiet');
        await moi(
          ManDanDuong(ten: dau.ten, viDo: dau.viDo, kinhDo: dau.kinhDo),
        );
        await chup('dan-duong');
        await ve();
        await ve();

        await tester.tap(find.byKey(const ValueKey('tab/cai-dat')));
        await doi();
        await moi(const ManQuyenRiengTu());
        await chup('rieng-tu');
        await ve();
        // Pro (M2b): ảnh thứ 7 - Cài đặt có "Bản quyền La bàn Pro" đã xác minh,
        // làm listing Pro khác bản miễn phí (chính sách nội dung lặp lại).
        if (_pro) {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('muc-ban-quyen-pro')),
            300,
            scrollable: find.byType(Scrollable).last,
          );
          await chup('ban-quyen');
        }

        // Qua mốc timer của app trước khi gỡ cây.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      });
    }
  }
}
