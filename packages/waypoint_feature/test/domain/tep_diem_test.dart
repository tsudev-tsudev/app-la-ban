import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

final mau = <DiemMoc>[
  const DiemMoc(
    id: '0b7c1f9e-0000-4000-8000-000000000001',
    ten: 'Hồ Gươm <Tháp Rùa> & "cầu Thê Húc"',
    viDo: 21.028511123456789,
    kinhDo: 105.85218200000001,
    caoDo: 12.345678,
    ghiChu: "Dòng 1\nDòng 2 - 'nháy' ✓ 😀",
    taoLuc: 1761800000123,
    suaLuc: 1761800999456,
  ),
  const DiemMoc(
    id: 'id-2',
    ten: 'Gần gốc toạ độ',
    viDo: 1e-7,
    kinhDo: -2.5e-9,
    taoLuc: 0,
    suaLuc: 1,
  ),
  const DiemMoc(
    id: 'id-3',
    ten: 'Cực nam, kinh tuyến đổi ngày',
    viDo: -90,
    kinhDo: 180,
    caoDo: -10.5,
    taoLuc: 1761800000000,
    suaLuc: 1761800000000,
  ),
];

DiemMoc tuNhap(DiemNhap n) => DiemMoc(
  id: n.id!,
  ten: n.ten!,
  viDo: n.viDo,
  kinhDo: n.kinhDo,
  caoDo: n.caoDo,
  ghiChu: n.ghiChu,
  taoLuc: n.taoLuc!,
  suaLuc: n.suaLuc!,
);

void main() {
  test('soThapPhan: không dùng mũ, đọc lại đúng từng bit', () {
    for (final x in [
      0.0,
      -0.0,
      1.0,
      21.028511123456789,
      1e-7,
      -2.5e-9,
      1.2345678901234567e-10,
      123456789012345680000.0,
      -180.0,
    ]) {
      final s = soThapPhan(x);
      expect(s, isNot(contains('e')), reason: s);
      expect(double.parse(s), x, reason: s);
    }
    expect(soThapPhan(12), '12');
    expect(soThapPhan(1e-7), '0.0000001');
  });

  for (final dd in DinhDangTep.values) {
    test('round-trip ${dd.name}: xuất -> nhập không mất dữ liệu', () {
      final s = dd == DinhDangTep.gpx
          ? xuatGpx(mau, luc: 1761800000000)
          : xuatKml(mau, tenTaiLieu: 'La bàn');
      expect(doanDinhDang(s), dd);
      final kq = nhapTep(s);
      expect(kq.boQua, 0);
      expect(kq.diem.map(tuNhap).toList(), mau);
    });
  }

  test('GPX của app khác: không tên, cmt thay desc, có trk bỏ qua, toạ độ '
      'hỏng bị bỏ', () {
    const s = '''
<?xml version="1.0"?>
<!DOCTYPE gpx [<!ENTITY x "xxxxxxxx">]>
<gpx:gpx xmlns:gpx="http://www.topografix.com/GPX/1/0" version="1.0">
  <!-- comment <wpt> -->
  <gpx:wpt lat='10.5' lon="106.25"><gpx:cmt><![CDATA[a < b & c]]></gpx:cmt></gpx:wpt>
  <gpx:wpt lat="abc" lon="1"/>
  <gpx:wpt lat="95" lon="1"><gpx:name>Sai</gpx:name></gpx:wpt>
  <gpx:wpt lat="1" lon="2"><gpx:name> &amp;x; &#x1F600; &#65; </gpx:name><gpx:ele>NaN</gpx:ele></gpx:wpt>
  <gpx:trk><gpx:trkseg><gpx:trkpt lat="1" lon="1"/></gpx:trkseg></gpx:trk>
</gpx:gpx>''';
    final kq = nhapTep(s);
    expect(kq.boQua, 2);
    expect(kq.diem, hasLength(2));
    expect(kq.diem[0].ten, isNull);
    expect(kq.diem[0].ghiChu, 'a < b & c');
    expect((kq.diem[0].viDo, kq.diem[0].kinhDo), (10.5, 106.25));
    expect(kq.diem[0].id, isNull);
    expect(kq.diem[1].ten, '&x; 😀 A');
    expect(kq.diem[1].caoDo, isNull);
  });

  test('KML Google Earth: Folder lồng, clampToGround bỏ cao độ 0', () {
    const s = '''
<kml xmlns="http://www.opengis.net/kml/2.2"><Document><Folder>
<Placemark><name>Đỉnh</name><Point><coordinates>
  103.775,22.3039,0
</coordinates></Point></Placemark>
<Placemark><name>Đường</name><LineString><coordinates>1,2 3,4</coordinates></LineString></Placemark>
</Folder></Document></kml>''';
    final kq = nhapTep(s);
    expect(kq.diem.single.ten, 'Đỉnh');
    expect(kq.diem.single.caoDo, isNull);
    expect(kq.diem.single.viDo, 22.3039);
    expect(kq.boQua, 1);
  });

  test('XML hỏng / không phải GPX-KML -> FormatException', () {
    for (final s in [
      '',
      'xin chào',
      '<gpx><wpt></gpx>',
      '<gpx></gpx><gpx/>',
      '<html><body/></html>',
      '<gpx a=b/>',
      '<${'a>' * 70}',
    ]) {
      expect(() => nhapTep(s), throwsFormatException, reason: s);
    }
  });

  test('quá $diemNhapToiDa điểm -> phần dư bị bỏ', () {
    final b = StringBuffer('<gpx>');
    for (var i = 0; i < diemNhapToiDa + 5; i++) {
      b.write('<wpt lat="1" lon="2"/>');
    }
    b.write('</gpx>');
    final kq = nhapTep(b.toString());
    expect(kq.diem, hasLength(diemNhapToiDa));
    expect(kq.boQua, 5);
  });

  test('keHoachNhap: thêm mới / cập nhật bản sửa sau / bỏ trùng / id lặp', () {
    final coSan = {for (final d in mau) d.id: d};
    final s = xuatGpx([
      mau[0],
      mau[1].copyWith(ten: 'Đổi tên', suaLuc: 99),
      mau[2].copyWith(ten: 'Cũ hơn', suaLuc: 0),
    ], luc: 0);
    final nhap = [
      ...nhapTep(s).diem,
      (
        id: null,
        ten: null,
        viDo: 1.0,
        kinhDo: 2.0,
        caoDo: null,
        ghiChu: '',
        taoLuc: null,
        suaLuc: null,
      ),
      // Cùng id với dòng đầu trong cùng tệp -> điểm mới.
      (
        id: mau[0].id,
        ten: 'Lặp',
        viDo: 1.0,
        kinhDo: 2.0,
        caoDo: null,
        ghiChu: '',
        taoLuc: 5,
        suaLuc: 5,
      ),
    ];
    var n = 0;
    final kh = keHoachNhap(
      nhap,
      coSan: coSan,
      bayGio: 777,
      tenMacDinh: (i) => 'Điểm $i',
      taoId: () => 'moi-${n++}',
    );
    expect(kh.trung, 2);
    expect(kh.capNhat.single.ten, 'Đổi tên');
    expect(kh.them.map((d) => (d.id, d.ten, d.taoLuc)), [
      ('moi-0', 'Điểm 1', 777),
      ('moi-1', 'Lặp', 5),
    ]);
  });
}
