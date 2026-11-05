import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:map_feature/map_feature.dart';
import 'package:test_kit/test_kit.dart';

/// 30/10/2026 10:00 UTC.
const gioThu = 1793354400000;

/// Kho vùng giả: danh sách định sẵn, tải phát tiến độ qua `dangTai`.
final class KhoVungGia implements KhoVungOffline {
  new([List<VungOffline>? ds]) : ds = ds ?? [];

  final List<VungOffline> ds;
  final daXoa = <int>[];
  final daTai = <({String ten, int zMin, int zMax, String urlKieu})>[];
  StreamController<TienDoTai>? dangTai;

  @override
  Future<List<VungOffline>> danhSach() async => List.of(ds);

  @override
  Future<int?> dungLuong() async => ds.isEmpty ? null : 42500000;

  @override
  Stream<TienDoTai> tai({
    required String ten,
    required KhungBanDo khung,
    required int zMin,
    required int zMax,
    required String urlKieu,
    required List<String> urlKieuPhu,
    required bool tongQuan,
    required int taoLuc,
  }) {
    daTai.add((ten: ten, zMin: zMin, zMax: zMax, urlKieu: urlKieu));
    return (dangTai = StreamController<TienDoTai>()).stream;
  }

  @override
  Future<void> xoa(int id) async {
    daXoa.add(id);
    ds.removeWhere((v) => v.id == id);
  }
}

final vungThu = <VungOffline>[
  (
    id: 1,
    ten: '',
    zMin: 0,
    zMax: 8,
    taoLuc: gioThu,
    tongQuan: true,
    khung: khungVietNam,
  ),
  (
    id: 2,
    ten: 'Vùng 30/10/2026 17:00',
    zMin: 9,
    zMax: 14,
    taoLuc: gioThu - 3600000,
    tongQuan: false,
    khung: (tay: 105.7, nam: 20.9, dong: 105.95, bac: 21.1),
  ),
];

/// Khung Hà Nội ở zoom 13 (vài trăm tile tới z14).
final class KhungHaNoi extends KhungDangXem {
  @override
  ({KhungBanDo khung, double zoom})? build() =>
      (khung: (tay: 105.80, nam: 21.00, dong: 105.88, bac: 21.06), zoom: 13);
}

Widget banDoThu(
  Widget man, {
  required OMaTran o,
  KhoVungOffline? kho,
  bool coKhung = true,
  List<Override> them = const [],
}) => ProviderScope(
  overrides: [
    banDoThatProvider.overrideWithValue(false),
    khoVungOfflineProvider.overrideWithValue(kho ?? KhoVungGia(vungThu)),
    gioBanDoProvider.overrideWithValue(() => gioThu),
    gioDiaPhuongBanDoProvider.overrideWithValue(
      (ms) => DateTime.fromMillisecondsSinceEpoch(
        ms,
        isUtc: true,
      ).add(const Duration(hours: 7)),
    ),
    if (coKhung) khungDangXemProvider.overrideWith(KhungHaNoi.new),
    ...them,
  ],
  child: khungThu(man, o: o),
);
