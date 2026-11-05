import 'package:app_shell/src/gioi_thieu.dart';
import 'package:app_shell/src/khung_dieu_huong.dart';
import 'package:app_shell/src/tab_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// Đường dẫn màn giới thiệu lần đầu.
const duongDanGioiThieu = '/chao';

/// Link chia sẻ điểm `https://compass.tsudev.com/w/<token>` (App Links) -
/// Flutter chuyển phần đường dẫn cho router.
const duongDanNhanDiem = '/w/:token';

/// Đích chuyển hướng: chưa xem giới thiệu / chưa trả lời bản thông báo dữ
/// liệu hiện hành -> [duongDanGioiThieu] (trừ link
/// chia sẻ điểm: xem được ngay, không mất link); đã xem mà còn ở màn đó ->
/// tab đầu; còn lại giữ nguyên (null).
@visibleForTesting
String? dichChuyenHuong({
  required bool daXemGioiThieu,
  required String viTri,
  required String tabDau,
}) {
  final oGioiThieu = viTri == duongDanGioiThieu;
  if (!daXemGioiThieu) {
    return oGioiThieu || viTri.startsWith('/w/') ? null : duongDanGioiThieu;
  }
  return oGioiThieu ? tabDau : null;
}

/// Router tạo MỘT lần cho cả vòng đời app (không watch) - đổi ngôn ngữ / theme
/// không tạo lại router nên không mất vị trí và state các tab.
final routerProvider = Provider<GoRouter>((ref) {
  final tabs = ref.read(dsTabProvider);
  final daXem = ValueNotifier<bool>(
    !ref.read(caiDatProvider.select((c) => c.canGioiThieu)),
  );
  ref.listen(
    caiDatProvider.select((c) => !c.canGioiThieu),
    (_, v) => daXem.value = v,
  );
  final router = GoRouter(
    initialLocation: tabs.first.duongDan,
    refreshListenable: daXem,
    // Link lạ (đường dẫn khác của compass.tsudev.com) -> về tab đầu thay vì
    // trang lỗi tiếng Anh mặc định.
    onException: (_, _, r) => r.go(tabs.first.duongDan),
    redirect: (context, state) => dichChuyenHuong(
      daXemGioiThieu: daXem.value,
      viTri: state.matchedLocation,
      tabDau: tabs.first.duongDan,
    ),
    routes: [
      GoRoute(
        path: duongDanGioiThieu,
        builder: (context, state) => const ManGioiThieu(),
      ),
      GoRoute(
        path: duongDanNhanDiem,
        // Khoá theo token: link /w/ mới khi đang ở màn này phải giải mã lại
        // (go_router giữ State khi chỉ đổi tham số đường dẫn - lỗi R3b, M32).
        builder: (context, state) => ManNhanDiem(
          key: ValueKey(state.pathParameters['token']),
          token: state.pathParameters['token']!,
          moDanhSach: () => context.go('/diem'),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => KhungDieuHuong(shell: shell),
        branches: [
          for (final t in tabs)
            StatefulShellBranch(
              routes: [
                GoRoute(path: t.duongDan, builder: (context, state) => t.man),
              ],
            ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    daXem.dispose();
  });
  return router;
});
