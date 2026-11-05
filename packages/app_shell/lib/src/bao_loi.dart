import 'dart:async';

import 'package:app_shell/src/cong_truc_tuyen.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';

/// Hàng đợi báo cáo sự cố trên máy (S10b, QUYET_DINH Q49): tệp JSON nhỏ
/// (`bao_cao_loi.json`) để sống qua lần app bị đóng vì lỗi; gửi ở lần mở sau.
final class HangBaoLoi {
  new(this._tep);

  final TepJson _tep;

  List<BaoCaoLoi> doc() => [
    for (final j in (_tep.duLieu['hang'] as List<Object?>?) ?? const [])
      ?BaoCaoLoi.tuJson(j),
  ];

  Future<void> them(BaoCaoLoi b) {
    final moi = themVaoHang(doc(), b);
    return _tep.ghi({
      'hang': [for (final x in moi) x.toJson()],
    });
  }

  /// Bỏ [n] bản đầu (đã gửi xong).
  Future<void> boDau(int n) {
    final con = doc().skip(n).toList();
    return _tep.ghi({
      'hang': [for (final x in con) x.toJson()],
    });
  }

  /// Rút đồng ý -> xoá luôn bản chưa gửi.
  Future<void> xoaHet() => _tep.ghi({'hang': <Object?>[]});
}

/// Bắt lỗi Flutter + lỗi không bắt của isolate chính, xếp vào [hang] CHỈ khi
/// [duocGhi] (người dùng đã bật báo cáo sự cố). Vẫn giữ hành vi gốc (in lỗi ở
/// debug). Lỗi trong chính bộ gom bị nuốt - báo cáo không được gây crash.
void batLoi(
  HangBaoLoi hang,
  bool Function() duocGhi,
  String phienBan, {
  int Function() dongHo = _bayGio,
}) {
  void ghi(String loai, Object loi, StackTrace? st) {
    try {
      if (!duocGhi()) return;
      unawaited(
        hang.them(
          taoBaoCaoLoi(
            loai: loai,
            loi: loi,
            phienBan: phienBan,
            luc: dongHo(),
            nganXep: st,
          ),
        ),
      );
    } on Object {
      // Bỏ qua.
    }
  }

  final goc = FlutterError.onError;
  FlutterError.onError = (chiTiet) {
    ghi('flutter', chiTiet.exception, chiTiet.stack);
    goc?.call(chiTiet);
  };
  final gocNen = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (loi, st) {
    ghi('dart', loi, st);
    return gocNen?.call(loi, st) ?? false;
  };
}

int _bayGio() => DateTime.now().millisecondsSinceEpoch;

/// Gửi lô báo cáo (<= [loGuiToiDa]) bằng yêu cầu ký thiết bị. 202 -> bỏ khỏi
/// hàng; lỗi mạng / 4xx -> giữ lại (4xx dữ liệu sai thì bỏ để không kẹt mãi).
@visibleForTesting
Future<void> guiBaoLoi(
  HangBaoLoi hang,
  Future<Result<PhanHoiKy>> Function(Map<String, Object?> than) gui,
) async {
  final ds = hang.doc().take(loGuiToiDa).toList();
  if (ds.isEmpty) return;
  final kq = await gui({
    'suCo': [for (final b in ds) b.toJson()],
  });
  if (kq case Ok(:final value)) {
    if (value.ok || value.status == 400 || value.status == 422) {
      await hang.boDau(ds.length);
    }
  }
}

/// Gửi sau khung đầu + mỗi lần quay lại foreground (cách >= [khoang]), chỉ
/// khi cổng trực tuyến mở VÀ người dùng bật báo cáo sự cố.
void batDauGuiBaoLoi(
  HangBaoLoi hang,
  DichVuDinhDanh dv,
  CongTrucTuyen cong,
  bool Function() duocGui, {
  Duration cho = const Duration(seconds: 10),
  Duration khoang = const Duration(minutes: 30),
}) {
  DateTime? lanCuoi;
  void chay() {
    if (!cong.value) return;
    if (!duocGui()) {
      if (hang.doc().isNotEmpty) unawaited(hang.xoaHet());
      return;
    }
    final bayGio = DateTime.now();
    if (lanCuoi != null && bayGio.difference(lanCuoi!) < khoang) return;
    lanCuoi = bayGio;
    unawaited(
      guiBaoLoi(
        hang,
        (than) => dv.goiKy('POST', '/v1/app/su-co', body: than),
      ).catchError((Object _) {}),
    );
  }

  WidgetsBinding.instance.addPostFrameCallback(
    (_) => Timer(
      cho,
      () => cong.khiMo(() {
        chay();
        AppLifecycleListener(onResume: chay);
      }),
    ),
  );
}
