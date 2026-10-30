import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:waypoint_feature/src/domain/diem_moc.dart';
import 'package:waypoint_feature/src/domain/tep_diem.dart';
import 'package:waypoint_feature/src/hien_thi.dart';
import 'package:waypoint_feature/src/providers.dart';

/// Tên tệp gợi ý: `la-ban-diem-20261030.gpx`.
String tenTepXuat(DinhDangTep dd, DateTime t) {
  String h(int v) => v.toString().padLeft(2, '0');
  return 'la-ban-diem-${t.year}${h(t.month)}${h(t.day)}.${dd.duoi}';
}

/// Xuất [ds] ra tệp qua hộp thoại "Lưu thành" của hệ thống.
Future<void> xuatTep(
  BuildContext context,
  WidgetRef ref,
  DinhDangTep dd,
  List<DiemMoc> ds,
) async {
  final l = context.l10n;
  final luc = ref.read(gioDiemProvider)();
  final noiDung = switch (dd) {
    DinhDangTep.gpx => xuatGpx(ds, luc: luc),
    DinhDangTep.kml => xuatKml(ds, tenTaiLieu: l.appTitle),
  };
  try {
    final ok = await ref
        .read(nenTangDiemProvider)
        .luuTep(
          tenTepXuat(dd, ref.read(gioDiaPhuongProvider)(luc)),
          dd.mime,
          utf8.encode(noiDung),
        );
    if (ok && context.mounted) baoNhanh(context, l.wpExported);
  } on PlatformException {
    if (context.mounted) baoNhanh(context, l.wpFileError);
  }
}

/// Chọn tệp GPX / KML, đọc ở isolate riêng (tệp lớn không giật giao diện),
/// ghép vào kho theo id.
Future<void> chonVaNhapTep(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final kho = ref.read(khoDiemProvider);
  if (kho == null) return;
  final Uint8List? byte;
  try {
    byte = await ref.read(nenTangDiemProvider).moTep();
  } on PlatformException {
    if (context.mounted) baoNhanh(context, l.wpFileError);
    return;
  }
  if (byte == null) return;
  final KetQuaNhap kq;
  try {
    kq = await Isolate.run(() {
      var s = utf8.decode(byte!, allowMalformed: true);
      if (s.startsWith('﻿')) s = s.substring(1);
      return nhapTep(s);
    });
  } on FormatException {
    if (context.mounted) baoNhanh(context, l.wpImportError);
    return;
  }
  if (kq.diem.isEmpty) {
    if (context.mounted) baoNhanh(context, l.wpImportEmpty);
    return;
  }
  final coSan = {for (final d in await kho.tatCa()) d.id: d};
  final kh = keHoachNhap(
    kq.diem,
    coSan: coSan,
    bayGio: ref.read(gioDiemProvider)(),
    tenMacDinh: l.wpUnnamed,
    taoId: ref.read(taoIdDiemProvider),
  );
  await kho.luuNhieu([...kh.them, ...kh.capNhat]);
  if (context.mounted) {
    baoNhanh(
      context,
      l.wpImportResult(kh.them.length, kh.capNhat.length, kh.trung + kq.boQua),
    );
  }
}
