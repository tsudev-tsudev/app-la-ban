import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:la_ban/src/gioi_thieu.dart';
import 'package:la_ban/src/khung_dieu_huong.dart';
import 'package:la_ban/src/tab_app.dart';
import 'package:settings_feature/settings_feature.dart';

/// Đường dẫn màn giới thiệu lần đầu.
const duongDanGioiThieu = '/chao';

/// Đích chuyển hướng: chưa xem giới thiệu -> [duongDanGioiThieu]; đã xem mà
/// còn ở màn đó -> tab đầu; còn lại giữ nguyên (null).
@visibleForTesting
String? dichChuyenHuong({
  required bool daXemGioiThieu,
  required String viTri,
  required String tabDau,
}) {
  final oGioiThieu = viTri == duongDanGioiThieu;
  if (!daXemGioiThieu) return oGioiThieu ? null : duongDanGioiThieu;
  return oGioiThieu ? tabDau : null;
}

/// Router tạo MỘT lần cho cả vòng đời app (không watch) - đổi ngôn ngữ / theme
/// không tạo lại router nên không mất vị trí và state các tab.
final routerProvider = Provider<GoRouter>((ref) {
  final tabs = ref.read(dsTabProvider);
  final daXem = ValueNotifier<bool>(
    ref.read(caiDatProvider.select((c) => c.daXemGioiThieu)),
  );
  ref.listen(
    caiDatProvider.select((c) => c.daXemGioiThieu),
    (_, v) => daXem.value = v,
  );
  final router = GoRouter(
    initialLocation: tabs.first.duongDan,
    refreshListenable: daXem,
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
