import 'package:waypoint_feature/src/domain/diem_moc.dart';
import 'package:waypoint_feature/src/domain/xml_nho.dart';

/// Định dạng tệp điểm hỗ trợ nhập / xuất.
enum DinhDangTep {
  gpx('gpx', 'application/gpx+xml'),
  kml('kml', 'application/vnd.google-earth.kml+xml');

  new(this.duoi, this.mime);

  final String duoi;
  final String mime;
}

/// Namespace mở rộng của app trong GPX (giữ id + giờ sửa để nhập lại không
/// mất dữ liệu). Không cần trỏ tới tài liệu thật.
const nsLaBan = 'https://compass.tsudev.com/xmlns/1';

/// Số điểm tối đa nhận trong một tệp (chống tệp quá lớn làm treo máy).
const diemNhapToiDa = 10000;

/// Một điểm đọc từ tệp. `id` / `suaLuc` chỉ có khi tệp do app này xuất;
/// `ten` null khi tệp không đặt tên (giao diện đặt tên mặc định).
typedef DiemNhap = ({
  String? id,
  String? ten,
  double viDo,
  double kinhDo,
  double? caoDo,
  String ghiChu,
  int? taoLuc,
  int? suaLuc,
});

/// Kết quả đọc tệp: các điểm hợp lệ + số điểm bị bỏ (toạ độ hỏng, quá hạn
/// mức).
typedef KetQuaNhap = ({List<DiemNhap> diem, int boQua});

String _gio(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

int? _docGio(String? s) =>
    s == null ? null : DateTime.tryParse(s)?.toUtc().millisecondsSinceEpoch;

/// Xuất GPX 1.1 (`wpt`). [luc] là giờ xuất (ms UTC) ghi ở metadata.
String xuatGpx(List<DiemMoc> ds, {required int luc}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="La ban - TsuDev" '
      'xmlns="http://www.topografix.com/GPX/1/1" xmlns:laban="$nsLaBan">',
    )
    ..writeln('  <metadata><time>${_gio(luc)}</time></metadata>');
  for (final d in ds) {
    b.writeln(
      '  <wpt lat="${soThapPhan(d.viDo)}" lon="${soThapPhan(d.kinhDo)}">',
    );
    if (d.caoDo != null) b.writeln('    <ele>${soThapPhan(d.caoDo!)}</ele>');
    b
      ..writeln('    <time>${_gio(d.taoLuc)}</time>')
      ..writeln('    <name>${thoatXml(d.ten)}</name>');
    if (d.ghiChu.isNotEmpty) {
      b.writeln('    <desc>${thoatXml(d.ghiChu)}</desc>');
    }
    b
      ..writeln('    <extensions>')
      ..writeln('      <laban:id>${thoatXml(d.id)}</laban:id>')
      ..writeln('      <laban:sua>${_gio(d.suaLuc)}</laban:sua>')
      ..writeln('    </extensions>')
      ..writeln('  </wpt>');
  }
  b.writeln('</gpx>');
  return b.toString();
}

/// Xuất KML 2.2 (`Placemark` + `Point`); id + giờ sửa ở `ExtendedData`.
String xuatKml(List<DiemMoc> ds, {required String tenTaiLieu}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
    ..writeln('<Document>')
    ..writeln('  <name>${thoatXml(tenTaiLieu)}</name>');
  for (final d in ds) {
    b
      ..writeln('  <Placemark>')
      ..writeln('    <name>${thoatXml(d.ten)}</name>');
    if (d.ghiChu.isNotEmpty) {
      b.writeln('    <description>${thoatXml(d.ghiChu)}</description>');
    }
    b
      ..writeln('    <TimeStamp><when>${_gio(d.taoLuc)}</when></TimeStamp>')
      ..writeln('    <ExtendedData>')
      ..writeln(
        '      <Data name="laban:id"><value>${thoatXml(d.id)}</value></Data>',
      )
      ..writeln(
        '      <Data name="laban:sua"><value>${_gio(d.suaLuc)}</value></Data>',
      )
      ..writeln('    </ExtendedData>')
      ..writeln('    <Point>');
    final toaDo = '${soThapPhan(d.kinhDo)},${soThapPhan(d.viDo)}';
    if (d.caoDo != null) {
      b
        ..writeln('      <altitudeMode>absolute</altitudeMode>')
        ..writeln(
          '      <coordinates>$toaDo,${soThapPhan(d.caoDo!)}</coordinates>',
        );
    } else {
      b.writeln('      <coordinates>$toaDo</coordinates>');
    }
    b
      ..writeln('    </Point>')
      ..writeln('  </Placemark>');
  }
  b
    ..writeln('</Document>')
    ..writeln('</kml>');
  return b.toString();
}

/// Đoán định dạng theo nội dung (không tin đuôi tệp). null = không nhận ra.
DinhDangTep? doanDinhDang(String s) {
  final dau = s.length > 4096 ? s.substring(0, 4096) : s;
  if (RegExp(r'<(\w+:)?gpx[\s>]').hasMatch(dau)) return DinhDangTep.gpx;
  if (RegExp(r'<(\w+:)?kml[\s>]').hasMatch(dau)) return DinhDangTep.kml;
  return null;
}

/// Đọc tệp GPX hoặc KML. Sai cú pháp / không phải GPX-KML ->
/// [FormatException].
KetQuaNhap nhapTep(String s) {
  final goc = docXml(s);
  return switch (goc.tenCucBo) {
    'gpx' => _gom(goc.hauDue('wpt').map(_tuWpt)),
    'kml' => _gom(goc.hauDue('Placemark').map(_tuPlacemark)),
    _ => throw FormatException('tep: gốc <${goc.ten}>'),
  };
}

KetQuaNhap _gom(Iterable<DiemNhap?> ds) {
  final ok = <DiemNhap>[];
  var bo = 0;
  for (final d in ds) {
    if (d == null || ok.length >= diemNhapToiDa) {
      bo++;
    } else {
      ok.add(d);
    }
  }
  return (diem: ok, boQua: bo);
}

double? _so(String? s) {
  final v = s == null ? null : double.tryParse(s.trim());
  return v != null && v.isFinite ? v : null;
}

DiemNhap? _hopLe({
  required String? id,
  required String? ten,
  required double? viDo,
  required double? kinhDo,
  required double? caoDo,
  required String? ghiChu,
  required int? taoLuc,
  required int? suaLuc,
}) {
  if (viDo == null || kinhDo == null) return null;
  final ghi = catChuoi(ghiChu ?? '', ghiChuToiDa);
  final t = ten == null ? null : catChuoi(ten.trim(), tenToiDa);
  final cao = caoDo != null && caoDo.abs() <= 20000 ? caoDo : null;
  if (kiemDiem(
    ten: t ?? 'x',
    viDo: viDo,
    kinhDo: kinhDo,
    ghiChu: ghi,
  ).isNotEmpty) {
    return null;
  }
  return (
    id: id,
    ten: (t?.isEmpty ?? true) ? null : t,
    viDo: viDo,
    kinhDo: kinhDo,
    caoDo: cao,
    ghiChu: ghi,
    taoLuc: taoLuc,
    suaLuc: suaLuc,
  );
}

String? _extLaBan(NutXml n, String ten) {
  final ext = n.motCon('extensions');
  if (ext == null) return null;
  for (final c in ext.con) {
    if (c.tenCucBo == ten && c.ten.contains(':')) {
      final t = c.chu.trim();
      return t.isEmpty ? null : t;
    }
  }
  return null;
}

DiemNhap? _tuWpt(NutXml w) => _hopLe(
  id: _extLaBan(w, 'id'),
  ten: w.chuCon('name'),
  viDo: _so(w.thuocTinh['lat']),
  kinhDo: _so(w.thuocTinh['lon']),
  caoDo: _so(w.chuCon('ele')),
  ghiChu: w.motCon('desc')?.chu ?? w.motCon('cmt')?.chu,
  taoLuc: _docGio(w.chuCon('time')),
  suaLuc: _docGio(_extLaBan(w, 'sua')),
);

DiemNhap? _tuPlacemark(NutXml p) {
  final diem = p.hauDue('Point').firstOrNull;
  final toaDo = diem?.chuCon('coordinates')?.split(',');
  if (diem == null || toaDo == null || toaDo.length < 2) return null;
  // KML mặc định clampToGround: cao độ (thường 0) không phải độ cao thật.
  final tuyetDoi = diem.chuCon('altitudeMode') == 'absolute';
  String? du(String ten) {
    for (final d in p.motCon('ExtendedData')?.hauDue('Data') ?? <NutXml>[]) {
      if (d.thuocTinh['name'] == ten) return d.chuCon('value');
    }
    return null;
  }

  return _hopLe(
    id: du('laban:id'),
    ten: p.chuCon('name'),
    viDo: _so(toaDo[1]),
    kinhDo: _so(toaDo[0]),
    caoDo: tuyetDoi && toaDo.length > 2 ? _so(toaDo[2]) : null,
    ghiChu: p.motCon('description')?.chu,
    taoLuc: _docGio(p.motCon('TimeStamp')?.chuCon('when')),
    suaLuc: _docGio(du('laban:sua')),
  );
}

/// Kế hoạch ghi một điểm nhập vào kho.
typedef KeHoachNhap = ({List<DiemMoc> them, List<DiemMoc> capNhat, int trung});

/// Ghép điểm nhập với [coSan] (theo id): id lạ / không có -> thêm mới (id
/// mới nếu thiếu); trùng id mà nội dung khác và bản nhập sửa SAU -> cập
/// nhật; còn lại bỏ (trùng). [tenMacDinh] đặt tên cho điểm không tên (thứ tự
/// từ 1).
KeHoachNhap keHoachNhap(
  List<DiemNhap> nhap, {
  required Map<String, DiemMoc> coSan,
  required int bayGio,
  required String Function(int thuTu) tenMacDinh,
  required String Function() taoId,
}) {
  final them = <DiemMoc>[];
  final capNhat = <DiemMoc>[];
  var trung = 0;
  var khongTen = 0;
  final daGap = <String>{};
  for (final n in nhap) {
    final ten = n.ten ?? tenMacDinh(++khongTen);
    // id lặp trong cùng tệp -> coi như điểm mới.
    final giuId = n.id != null && daGap.add(n.id!);
    final cu = giuId ? coSan[n.id] : null;
    final d = DiemMoc(
      id: giuId ? n.id! : taoId(),
      ten: ten,
      viDo: n.viDo,
      kinhDo: n.kinhDo,
      caoDo: n.caoDo,
      ghiChu: n.ghiChu,
      taoLuc: n.taoLuc ?? bayGio,
      suaLuc: n.suaLuc ?? n.taoLuc ?? bayGio,
    );
    if (cu == null) {
      them.add(d);
    } else if (cu == d || d.suaLuc <= cu.suaLuc) {
      trung++;
    } else {
      capNhat.add(d);
    }
  }
  return (them: them, capNhat: capNhat, trung: trung);
}
