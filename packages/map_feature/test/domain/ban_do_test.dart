import 'package:flutter_test/flutter_test.dart';
import 'package:map_feature/map_feature.dart';

void main() {
  test('URL style theo giao diện + ngôn ngữ, ngôn ngữ lạ -> en', () {
    const g = 'https://compass-api.tsudev.com';
    expect(
      urlKieuBanDo(g, toi: false, ngonNgu: 'vi'),
      '$g/ban-do/kieu/sang-vi.json',
    );
    expect(
      urlKieuBanDo(g, toi: true, ngonNgu: 'fr'),
      '$g/ban-do/kieu/toi-en.json',
    );
    expect(moiUrlKieu(g).toSet().length, 4);
  });

  test('số tile: một tile z14 Hà Nội, cắt theo khung VN, ngoài VN = 0', () {
    const haNoi = (tay: 105.85, nam: 21.03, dong: 105.85, bac: 21.03);
    expect(soTileVung(haNoi, 14, 14), 1);
    expect(soTileVung(haNoi, 0, 14), 15);
    const paris = (tay: 2.2, nam: 48.8, dong: 2.4, bac: 48.9);
    expect(soTileVung(paris, 0, 14), 0);
    // Cả thế giới bị cắt về khung VN: bằng đúng số tile của khung VN.
    const theGioi = (tay: -180.0, nam: -80.0, dong: 180.0, bac: 80.0);
    expect(
      soTileVung(theGioi, 0, zoomTongQuan),
      soTileVung(khungVietNam, 0, zoomTongQuan),
    );
    expect(soTileVung(khungVietNam, 0, zoomTongQuan), lessThan(1000));
  });

  test('zoom bắt đầu vùng: thấp hơn 4 mức, kẹp 0..14', () {
    expect(zoomBatDauVung(12.7), 8);
    expect(zoomBatDauVung(2), 0);
    expect(zoomBatDauVung(20), 14);
  });

  test('GeoJSON điểm: [kinh, vĩ], thuộc tính id + tên', () {
    final g = geoJsonDiem([
      (id: 'a', ten: 'Hồ Gươm', viDo: 21.03, kinhDo: 105.85),
    ]);
    final f = (g['features']! as List).single as Map;
    expect((f['geometry'] as Map)['coordinates'], [105.85, 21.03]);
    expect(f['properties'], {'id': 'a', 'ten': 'Hồ Gươm'});
  });

  test('GeoJSON vị trí: vòng sai số 20 m ở z22 lớn hơn z0 đúng 2^22', () {
    expect(geoJsonViTri(null)['features']! as List, isEmpty);
    final f =
        (geoJsonViTri((viDo: 21.0, kinhDo: 105.8, saiSoM: 20))['features']!
                    as List)
                .single
            as Map;
    final p = f['properties'] as Map;
    expect((p['r22'] as double) / (p['r0'] as double), closeTo(4194304, 1));
    // z18 ở vĩ độ 21: ~0,28 m / điểm ảnh -> 20 m ~ 71 điểm ảnh.
    expect(20 / metMoiDiemAnh(21, 18), closeTo(71, 2));
  });

  test('lệch góc qua 0°', () {
    expect(lechGoc(359, 1), 2);
    expect(lechGoc(10, 350), 20);
    expect(lechGoc(90, 270), 180);
  });
}
