import 'dart:async';
import 'dart:math' show Point;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:map_feature/src/domain/ban_do.dart';
import 'package:map_feature/src/icon_ban_do.dart';
import 'package:map_feature/src/man_vung_offline.dart';
import 'package:map_feature/src/providers.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

/// Tab Bản đồ (A7b): MapLibre + tile vector của Worker /ban-do (QUYET_DINH
/// Q38), lớp điểm, chấm vị trí + vòng sai
/// số, xoay theo hướng, vùng offline.
class ManBanDo extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ManBanDo> createState() => _ManBanDoState();
}

const _nguonDiem = 'diem';
const _nguonViTri = 'vi-tri';

final _cameraDau = ml.CameraPosition(
  target: ml.LatLng(tamMacDinh.viDo, tamMacDinh.kinhDo),
  zoom: tamMacDinh.zoom,
);

class _ManBanDoState extends ConsumerState<ManBanDo> {
  ml.MapLibreMapController? _ct;
  bool _styleXong = false;
  bool _theoHuong = false;
  bool _daVeViTri = false;
  double? _huongDaDat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mau = Theme.of(context).colorScheme;
    // Tab ẩn có TickerMode tắt: thôi nghe GPS / cảm biến (như tab La bàn).
    final dangThay = TickerMode.valuesOf(context).enabled;
    if (dangThay) {
      ref.listen(viTriBanDoProvider, (_, v) => unawaited(_capNhatViTri(v)));
      if (_theoHuong) {
        ref.listen(huongBanDoProvider, (_, h) => unawaited(_xoayTheo(h)));
      }
    }
    ref.listen(diemBanDoProvider, (_, ds) => unawaited(_capNhatDiem(ds)));
    final toi = Theme.of(context).brightness == Brightness.dark;
    final ngonNgu = Localizations.localeOf(context).languageCode;
    final url = urlKieuBanDo(
      ref.watch(gocBanDoProvider),
      toi: toi,
      ngonNgu: ngonNgu,
    );
    final banDo = ref.watch(banDoThatProvider)
        ? ml.MapLibreMap(
            styleString: url,
            initialCameraPosition: _cameraDau,
            trackCameraPosition: true,
            attributionButtonPosition: ml.AttributionButtonPosition.bottomLeft,
            onMapCreated: (c) => _ct = c,
            onStyleLoadedCallback: () => unawaited(_khiStyleXong()),
            onCameraIdle: () => unawaited(_khiCameraDung()),
            onMapClick: (p, _) => unawaited(_khiCham(p)),
          )
        : ColoredBox(color: mau.surface);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabMap),
        actions: [
          IconButton(
            tooltip: l10n.mapOffline,
            icon: const LbIcon(IconBanDo.taiVe),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ManVungOffline()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: banDo),
          PositionedDirectional(
            end: LbSpacing.lg,
            bottom: LbSpacing.xl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'ban-do-huong',
                  tooltip: _theoHuong ? l10n.mapNorthUp : l10n.mapFollowHeading,
                  onPressed: _doiTheoHuong,
                  child: LbIcon(
                    _theoHuong ? LbIcons.bacThuc : LbIcons.laBanHoaGio,
                  ),
                ),
                const SizedBox(height: LbSpacing.md),
                FloatingActionButton(
                  heroTag: 'ban-do-vi-tri',
                  tooltip: l10n.mapMyLocation,
                  onPressed: _veViTri,
                  child: const LbIcon(LbIcons.ghimGps),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _khiStyleXong() async {
    final c = _ct;
    if (c == null) return;
    // Đổi style (giao diện / ngôn ngữ) xoá lớp tự thêm -> thêm lại mỗi lần.
    _styleXong = false;
    final mau = Theme.of(context).colorScheme;
    String hex(Color m) =>
        '#${(m.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    await c.addGeoJsonSource(
      _nguonDiem,
      geoJsonDiem(ref.read(diemBanDoProvider)),
    );
    await c.addCircleLayer(
      _nguonDiem,
      'diem-cham',
      ml.CircleLayerProperties(
        circleRadius: 7,
        circleColor: hex(mau.secondary),
        circleStrokeWidth: 2,
        circleStrokeColor: hex(mau.surface),
      ),
    );
    await c.addSymbolLayer(
      _nguonDiem,
      'diem-ten',
      ml.SymbolLayerProperties(
        textField: [ml.Expressions.get, 'ten'],
        textFont: ['Noto Sans Medium'],
        textSize: 13,
        textOffset: [0, 1.2],
        textAnchor: 'top',
        textOptional: true,
        textColor: hex(mau.onSurface),
        textHaloColor: hex(mau.surface),
        textHaloWidth: 1.5,
      ),
      minzoom: 10,
    );
    await c.addGeoJsonSource(_nguonViTri, geoJsonViTri(null));
    await c.addCircleLayer(
      _nguonViTri,
      'vi-tri-sai-so',
      ml.CircleLayerProperties(
        circleRadius: [
          'interpolate',
          ['exponential', 2],
          ['zoom'],
          0,
          ['get', 'r0'],
          22,
          ['get', 'r22'],
        ],
        circleColor: hex(mau.primary),
        circleOpacity: 0.15,
        circlePitchAlignment: 'map',
      ),
    );
    await c.addCircleLayer(
      _nguonViTri,
      'vi-tri-cham',
      ml.CircleLayerProperties(
        circleRadius: 8,
        circleColor: hex(mau.primary),
        circleStrokeWidth: 3,
        circleStrokeColor: '#FFFFFF',
      ),
    );
    _styleXong = true;
    await _capNhatViTri(ref.read(viTriBanDoProvider));
  }

  Future<void> _capNhatDiem(List<DiemBanDo> ds) async {
    final c = _ct;
    if (c == null || !_styleXong) return;
    await c.setGeoJsonSource(_nguonDiem, geoJsonDiem(ds));
  }

  Future<void> _capNhatViTri(ViTriBanDo? v) async {
    final c = _ct;
    if (c == null || !_styleXong) return;
    await c.setGeoJsonSource(_nguonViTri, geoJsonViTri(v));
    // Lần đầu có vị trí: đưa bản đồ tới đó (người dùng mở tab để xem quanh
    // mình).
    if (v != null && !_daVeViTri) {
      _daVeViTri = true;
      await c.animateCamera(
        ml.CameraUpdate.newLatLngZoom(ml.LatLng(v.viDo, v.kinhDo), 14),
      );
    }
  }

  Future<void> _xoayTheo(double? h) async {
    final c = _ct;
    if (c == null || h == null) return;
    final cu = _huongDaDat;
    if (cu != null && lechGoc(cu, h) < 3) return;
    _huongDaDat = h;
    await c.moveCamera(ml.CameraUpdate.bearingTo(h));
  }

  void _doiTheoHuong() {
    setState(() => _theoHuong = !_theoHuong);
    _huongDaDat = null;
    if (!_theoHuong) {
      unawaited(_ct?.animateCamera(ml.CameraUpdate.bearingTo(0)));
    }
  }

  Future<void> _veViTri() async {
    if (!ref.read(coQuyenViTriBanDoProvider)) {
      await ref.read(xinQuyenViTriBanDoProvider)();
      return;
    }
    final v = ref.read(viTriBanDoProvider);
    if (v == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.mapNoLocation)));
      return;
    }
    _daVeViTri = true;
    final z = _ct?.cameraPosition?.zoom ?? 0;
    await _ct?.animateCamera(
      ml.CameraUpdate.newLatLngZoom(
        ml.LatLng(v.viDo, v.kinhDo),
        z < 14 ? 15 : z,
      ),
    );
  }

  Future<void> _khiCameraDung() async {
    final c = _ct;
    if (c == null) return;
    final b = await c.getVisibleRegion();
    ref.read(khungDangXemProvider.notifier).dat((
      tay: b.southwest.longitude,
      nam: b.southwest.latitude,
      dong: b.northeast.longitude,
      bac: b.northeast.latitude,
    ), c.cameraPosition?.zoom ?? 0);
  }

  Future<void> _khiCham(Point<double> p) async {
    final c = _ct;
    final mo = ref.read(moDiemBanDoProvider);
    if (c == null || mo == null || !_styleXong) return;
    final ds = await c.queryRenderedFeatures(p, [
      'diem-cham',
      'diem-ten',
    ], null);
    if (ds.isEmpty || !mounted) return;
    final dau = ds.first;
    final thuocTinh = dau is Map ? dau['properties'] : null;
    final id = thuocTinh is Map ? thuocTinh['id'] : null;
    if (id is String) mo(context, id);
  }
}
