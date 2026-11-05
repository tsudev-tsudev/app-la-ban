import 'dart:async';
import 'dart:io';

import 'package:map_feature/src/domain/ban_do.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

/// Một vùng đã tải để dùng không cần mạng.
typedef VungOffline = ({
  int id,
  String ten,
  int zMin,
  int zMax,

  /// ms UTC.
  int taoLuc,

  /// Gói "Tổng quan Việt Nam" (cả nước, zoom thấp).
  bool tongQuan,

  /// Khung đã tải (M2b: chuyển định nghĩa vùng sang La bàn Pro); null khi
  /// plugin không trả.
  KhungBanDo? khung,
});

/// Tiến độ tải: `daXong` / `tong` tài nguyên (tile + style + glyph), `byte`
/// đã nhận.
typedef TienDoTai = ({int daXong, int tong, int byte});

/// Vùng offline: MapLibre Native giữ tile trong CSDL riêng của nó (offline
/// region); lớp này chỉ bọc API plugin để
/// màn hình test được bằng bản giả.
abstract interface class KhoVungOffline {
  Future<List<VungOffline>> danhSach();

  /// Tải vùng theo style [urlKieu]; style ở [urlKieuPhu] lưu kèm (đổi giao diện
  /// / ngôn ngữ khi không mạng). Luồng
  /// đóng khi xong; lỗi = lỗi của luồng.
  Stream<TienDoTai> tai({
    required String ten,
    required KhungBanDo khung,
    required int zMin,
    required int zMax,
    required String urlKieu,
    required List<String> urlKieuPhu,
    required bool tongQuan,
    required int taoLuc,
  });

  Future<void> xoa(int id);

  /// Byte CSDL offline (mọi vùng + bộ nhớ đệm); null khi chưa có.
  Future<int?> dungLuong();
}

final class KhoVungMapLibre implements KhoVungOffline {
  const new();

  static bool _daDatTran = false;

  static Future<void> _datTran() async {
    if (_daDatTran) return;
    _daDatTran = true;
    // Trần của MapLibre tính cả vùng phụ; gói tổng quan + một vùng lớn nhất vẫn
    // lọt.
    await ml.setOfflineTileCountLimit(tileToiDaMotVung * 4);
  }

  static VungOffline? _doc(ml.OfflineRegion r) {
    final m = r.metadata;
    if (m['phu'] == true) return null;
    return (
      id: r.id,
      ten: (m['ten'] as String?) ?? '',
      zMin: r.definition.minZoom.round(),
      zMax: r.definition.maxZoom.round(),
      taoLuc: (m['taoLuc'] as num?)?.toInt() ?? 0,
      tongQuan: m['tongQuan'] == true,
      khung: _khung(r.definition.bounds),
    );
  }

  static KhungBanDo _khung(ml.LatLngBounds b) => (
    tay: b.southwest.longitude,
    nam: b.southwest.latitude,
    dong: b.northeast.longitude,
    bac: b.northeast.latitude,
  );

  @override
  Future<List<VungOffline>> danhSach() async {
    final ds = [for (final r in await ml.getListOfRegions()) ?_doc(r)]
      ..sort((a, b) => b.taoLuc.compareTo(a.taoLuc));
    return ds;
  }

  Future<void> _taiMot(
    ml.OfflineRegionDefinition dn,
    Map<String, dynamic> meta,
    void Function(ml.InProgress e)? onTien, {
    void Function(int id)? onId,
  }) async {
    final xong = Completer<void>();
    final r = await ml.downloadOfflineRegion(
      dn,
      metadata: meta,
      onEvent: (e) {
        switch (e) {
          case ml.InProgress():
            onTien?.call(e);
          case ml.Success():
            if (!xong.isCompleted) xong.complete();
          case ml.Error(:final cause):
            if (!xong.isCompleted) xong.completeError(cause);
        }
      },
    );
    onId?.call(r.id);
    await xong.future;
  }

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
    final ra = StreamController<TienDoTai>();
    Future<void> chay() async {
      await _datTran();
      int? id;
      try {
        await _taiMot(
          ml.OfflineRegionDefinition(
            bounds: ml.LatLngBounds(
              southwest: ml.LatLng(khung.nam, khung.tay),
              northeast: ml.LatLng(khung.bac, khung.dong),
            ),
            mapStyleUrl: urlKieu,
            minZoom: zMin.toDouble(),
            maxZoom: zMax.toDouble(),
          ),
          {'ten': ten, 'taoLuc': taoLuc, 'tongQuan': tongQuan},
          (e) => ra.add((
            daXong: e.completedResourceCount,
            tong: e.requiredResourceCount,
            byte: e.completedResourceSize,
          )),
          onId: (v) => id = v,
        );
        // Style còn lại: vùng phụ siêu nhỏ (z0) chỉ để lưu tệp style; tile dùng
        // chung URL với vùng chính.
        for (final u in urlKieuPhu) {
          await _taiMot(
            ml.OfflineRegionDefinition(
              bounds: ml.LatLngBounds(
                southwest: ml.LatLng(khung.nam, khung.tay),
                northeast: ml.LatLng(khung.nam, khung.tay),
              ),
              mapStyleUrl: u,
              minZoom: 0,
              maxZoom: 0,
            ),
            {'phu': true, 'cha': id},
            null,
          );
        }
      } on Object catch (e, st) {
        if (id != null) await xoa(id!);
        ra.addError(e, st);
      } finally {
        await ra.close();
      }
    }

    unawaited(chay());
    return ra.stream;
  }

  @override
  Future<void> xoa(int id) async {
    for (final r in await ml.getListOfRegions()) {
      if (r.id == id || r.metadata['cha'] == id) {
        await ml.deleteOfflineRegion(r.id);
      }
    }
  }

  @override
  Future<int?> dungLuong() async {
    final p = await ml.getOfflineDatabasePath();
    if (p == null) return null;
    var tong = 0;
    for (final duoi in ['', '-wal']) {
      final f = File('$p$duoi');
      if (f.existsSync()) tong += f.lengthSync();
    }
    return tong == 0 ? null : tong;
  }
}
