import 'dart:math' as math;

// A7b - phần thuần của tab Bản đồ: URL style / tile (Worker /ban-do, QUYET_DINH
// Q38), GeoJSON lớp điểm + vị trí,
// ước lượng số tile của vùng offline.

/// [tây, nam, đông, bắc]: đất liền + Hoàng Sa + Trường Sa - khớp `KHUNG_VN` ở
/// workers/api/src/thuan/ban-do.ts.
const KhungBanDo khungVietNam = (tay: 102.1, nam: 6.0, dong: 117.9, bac: 23.45);

/// Zoom lớn nhất có tile (z14); MapLibre phóng tiếp từ z14.
const zoomTileToiDa = 14;

/// Zoom tối đa của gói "Tổng quan Việt Nam" (cả nước, vài trăm tile).
const zoomTongQuan = 8;

/// Trần số tile một vùng tải về (đặt cho MapLibre bằng
/// setOfflineTileCountLimit). Một vùng thành phố ở z14 cỡ vài
/// nghìn tile; quá trần -> người dùng phóng to rồi tải vùng nhỏ hơn.
const tileToiDaMotVung = 6000;

/// Tâm + zoom mặc định khi chưa có vị trí: thấy cả nước.
const ({double viDo, double kinhDo, double zoom}) tamMacDinh = (
  viDo: 16.0,
  kinhDo: 106.0,
  zoom: 4.6,
);

typedef KhungBanDo = ({double tay, double nam, double dong, double bac});

/// Style MapLibre do Worker sinh: `<gốc>/ban-do/kieu/<sang|toi>-<vi|en>.json`.
/// Ngôn ngữ khác vi -> en.
String urlKieuBanDo(String goc, {required bool toi, required String ngonNgu}) =>
    '$goc/ban-do/kieu/${toi ? 'toi' : 'sang'}-${ngonNgu == 'vi' ? 'vi' : 'en'}.json';

/// Tất cả style của một gốc - vùng offline lưu kèm style kia để đổi giao diện /
/// ngôn ngữ khi không có mạng.
List<String> moiUrlKieu(String goc) => [
  for (final toi in [false, true])
    for (final nn in ['vi', 'en']) urlKieuBanDo(goc, toi: toi, ngonNgu: nn),
];

int _tileX(double kinhDo, int z) =>
    (((kinhDo + 180) / 360) * (1 << z)).floor().clamp(0, (1 << z) - 1);

int _tileY(double viDo, int z) {
  final r = viDo.clamp(-85.0511, 85.0511) * math.pi / 180;
  final y = (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2;
  return (y * (1 << z)).floor().clamp(0, (1 << z) - 1);
}

/// Số tile vector của khung ở zoom [zMin]..[zMax], CHỈ phần giao khung Việt Nam
/// (ngoài vùng Worker trả 204, rẻ).
int soTileVung(KhungBanDo k, int zMin, int zMax) {
  final tay = math.max(k.tay, khungVietNam.tay);
  final dong = math.min(k.dong, khungVietNam.dong);
  final nam = math.max(k.nam, khungVietNam.nam);
  final bac = math.min(k.bac, khungVietNam.bac);
  if (tay > dong || nam > bac) return 0;
  var tong = 0;
  for (var z = zMin; z <= zMax; z++) {
    tong +=
        (_tileX(dong, z) - _tileX(tay, z) + 1) *
        (_tileY(nam, z) - _tileY(bac, z) + 1);
  }
  return tong;
}

/// Zoom nhỏ nhất đáng tải cho vùng: thấp hơn zoom đang xem 4 mức (đủ ngữ cảnh
/// khi thu nhỏ), không dưới gói tổng quan.
int zoomBatDauVung(double zoomDangXem) =>
    math.max(0, math.min(zoomTileToiDa, zoomDangXem.floor() - 4));

/// Một điểm vẽ trên bản đồ.
typedef DiemBanDo = ({String id, String ten, double viDo, double kinhDo});

/// FeatureCollection lớp điểm (thuộc tính `id`, `ten` cho nhãn + chạm mở chi
/// tiết).
Map<String, Object?> geoJsonDiem(Iterable<DiemBanDo> ds) => {
  'type': 'FeatureCollection',
  'features': [
    for (final d in ds)
      {
        'type': 'Feature',
        'id': d.id,
        'properties': {'id': d.id, 'ten': d.ten},
        'geometry': {
          'type': 'Point',
          'coordinates': [d.kinhDo, d.viDo],
        },
      },
  ],
};

/// Vị trí hiện tại trên bản đồ.
typedef ViTriBanDo = ({double viDo, double kinhDo, double? saiSoM});

/// FeatureCollection chấm vị trí. `r0` / `r22`: bán kính vòng sai số (điểm ảnh)
/// ở zoom 0 / 22 - style nội suy mũ 2
/// theo zoom nên vòng giữ đúng cỡ mét khi phóng. null -> rỗng.
Map<String, Object?> geoJsonViTri(ViTriBanDo? v) => {
  'type': 'FeatureCollection',
  'features': [
    if (v != null)
      {
        'type': 'Feature',
        'properties': {
          'r0': (v.saiSoM ?? 0) / metMoiDiemAnh(v.viDo, 0),
          'r22': (v.saiSoM ?? 0) / metMoiDiemAnh(v.viDo, 22),
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [v.kinhDo, v.viDo],
        },
      },
  ],
};

/// Mét trên một điểm ảnh logic ở vĩ độ / zoom (Web Mercator, ô 512) - đổi vòng
/// sai số sang bán kính vẽ.
double metMoiDiemAnh(double viDo, double zoom) =>
    40075016.686 * math.cos(viDo * math.pi / 180) / (512 * math.pow(2, zoom));

/// Góc lệch nhỏ nhất (độ) giữa hai phương vị - xoay bản đồ theo hướng chỉ khi
/// lệch đủ lớn (đỡ giật, đỡ tốn pin).
double lechGoc(double a, double b) {
  final d = ((a - b) % 360 + 360) % 360;
  return d > 180 ? 360 - d : d;
}
