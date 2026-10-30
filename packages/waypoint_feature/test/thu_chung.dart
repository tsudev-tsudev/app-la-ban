import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:sensors/sensors.dart';
import 'package:test_kit/test_kit.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// 30/10/2026 10:00 UTC.
const gioThu = 1793354400000;

final diemThu = <DiemMoc>[
  const DiemMoc(
    id: 'a',
    ten: 'Hồ Gươm',
    viDo: 21.0285111,
    kinhDo: 105.8521822,
    caoDo: 12.3,
    ghiChu: 'Gặp ở cổng đền Ngọc Sơn',
    taoLuc: gioThu,
    suaLuc: gioThu,
  ),
  const DiemMoc(
    id: 'b',
    ten: 'Đỉnh Fansipan - nóc nhà Đông Dương, đường lên dài và rất dốc',
    viDo: 22.303889,
    kinhDo: 103.775,
    caoDo: 3143,
    taoLuc: gioThu - 1000,
    suaLuc: gioThu - 1000,
  ),
];

/// Nền tảng giả: ghi lại lời gọi, trả tệp / ảnh định sẵn.
final class NenTangGia implements NenTangDiem {
  Uint8List? tepMo;
  AnhMoi? anh;
  final luu = <(String, String, String)>[];
  final chiaSe = <String>[];

  @override
  Future<AnhMoi?> chonAnh() async => anh;

  @override
  Future<void> chiaSeChu(String chu, {required String tieuDe}) async =>
      chiaSe.add(chu);

  @override
  Future<bool> luuTep(String tenGoiY, String mime, Uint8List duLieu) async {
    luu.add((tenGoiY, mime, utf8.decode(duLieu)));
    return true;
  }

  @override
  Future<Uint8List?> moTep() async => tepMo;
}

HuongDoc huong(double phuongVi) => HuongDoc(
  phuongVi: phuongVi,
  phuongViTho: phuongVi,
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
);

/// Ghi đè chung: đồng hồ + id cố định, kho, nền tảng giả.
List<Override> ghiDe({
  KhoDiem? kho,
  NenTangDiem? nenTang,
  TrangThaiViTri viTri = const ViTriChuaCoQuyen(),
  bool khongKho = false,
  bool chiaSe = true,
  Stream<HuongDoc>? luongHuong,
}) {
  var n = 0;
  return [
    if (!khongKho) khoDiemProvider.overrideWithValue(kho ?? KhoDiemBoNho()),
    nenTangDiemProvider.overrideWithValue(nenTang ?? NenTangGia()),
    gioDiemProvider.overrideWithValue(() => gioThu),
    // Giờ Việt Nam cố định (UTC+7), không theo máy chạy test.
    gioDiaPhuongProvider.overrideWithValue(
      (ms) => DateTime.fromMillisecondsSinceEpoch(
        ms,
        isUtc: true,
      ).add(const Duration(hours: 7)),
    ),
    taoIdDiemProvider.overrideWithValue(() => 'id-${n++}'),
    viTriDiemProvider.overrideWithValue(viTri),
    choPhepChiaSeProvider.overrideWithValue(chiaSe),
    dongHoProvider.overrideWithValue(() => DateTime.utc(2026, 10, 30)),
    huongProvider.overrideWith((ref) => luongHuong ?? Stream.value(huong(0))),
  ];
}

Widget dung(Widget man, OMaTran o, List<Override> ds) => ProviderScope(
  overrides: ds,
  child: khungThu(man, o: o),
);
