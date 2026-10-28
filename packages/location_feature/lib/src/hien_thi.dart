import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:location_feature/src/domain/doc_vi_tri.dart';
import 'package:location_feature/src/domain/thien_van.dart';
import 'package:location_feature/src/domain/toa_do.dart';
import 'package:sensors/sensors.dart';

String tenDinhDang(LbL10n l, DinhDangToaDo d) => switch (d) {
  DinhDangToaDo.dd => l.locFormatDd,
  DinhDangToaDo.dms => l.locFormatDms,
  DinhDangToaDo.utm => l.locFormatUtm,
  DinhDangToaDo.mgrs => l.locFormatMgrs,
};

String tenNguon(LbL10n l, NguonDocViTri n) => switch (n) {
  NguonDocViTri.gps => l.locSourceGps,
  NguonDocViTri.mang => l.locSourceNetwork,
  NguonDocViTri.hopNhat || NguonDocViTri.khac => l.locSourceFused,
};

String tenPhaTrang(LbL10n l, TenPhaTrang p) => switch (p) {
  TenPhaTrang.trangMoi => l.moonNew,
  TenPhaTrang.luoiLiemDau => l.moonWaxingCrescent,
  TenPhaTrang.thuongHuyen => l.moonFirstQuarter,
  TenPhaTrang.traiMoDau => l.moonWaxingGibbous,
  TenPhaTrang.trangTron => l.moonFull,
  TenPhaTrang.traiMoCuoi => l.moonWaningGibbous,
  TenPhaTrang.haHuyen => l.moonLastQuarter,
  TenPhaTrang.luoiLiemCuoi => l.moonWaningCrescent,
};

/// Lệch múi giờ của máy tại một thời điểm (test override để ảnh golden
/// không phụ thuộc múi giờ máy chạy test).
final lechMuiGioProvider = Provider<Duration Function(DateTime)>(
  (_) =>
      (t) => t.toLocal().timeZoneOffset,
);

/// Thời điểm hiện tại, nhích mỗi phút (mặt trời / mặt trăng không cần nhanh
/// hơn). Đọc đồng hồ qua `dongHoProvider` để test cố định được.
final StreamProvider<DateTime> phutProvider = StreamProvider.autoDispose((ref) {
  final dongHo = ref.watch(dongHoProvider);
  final ra = StreamController<DateTime>()..add(dongHo());
  final t = Timer.periodic(const Duration(minutes: 1), (_) => ra.add(dongHo()));
  ref.onDispose(() {
    t.cancel();
    ra.close().ignore();
  });
  return ra.stream;
});

/// Giờ:phút theo định dạng máy, ở múi giờ của máy.
String gioPhut(BuildContext context, WidgetRef ref, DateTime t) {
  final lech = ref.read(lechMuiGioProvider)(t);
  final dl = t.toUtc().add(lech);
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: dl.hour, minute: dl.minute),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Nửa đêm hôm nay ở múi giờ máy, quy ra UTC.
DateTime nuaDemHomNay(DateTime bayGio, Duration lech) {
  final dl = bayGio.toUtc().add(lech);
  return DateTime.utc(dl.year, dl.month, dl.day).subtract(lech);
}
