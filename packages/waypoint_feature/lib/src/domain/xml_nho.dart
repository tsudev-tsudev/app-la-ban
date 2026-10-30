/// Bộ đọc XML tối giản, đủ cho GPX / KML (không phụ thuộc gói ngoài).
/// KHÔNG xử lý DTD / thực thể tự khai báo (bỏ qua `<!DOCTYPE>`) -> không bị
/// tấn công mở rộng thực thể (billion laughs, XXE).
library;

/// Một phần tử XML. [ten] giữ nguyên tiền tố (`laban:id`).
final class NutXml {
  new(this.ten, this.thuocTinh);

  final String ten;
  final Map<String, String> thuocTinh;
  final List<NutXml> con = [];
  final StringBuffer _chu = StringBuffer();

  /// Tên bỏ tiền tố namespace.
  String get tenCucBo {
    final i = ten.indexOf(':');
    return i < 0 ? ten : ten.substring(i + 1);
  }

  /// Văn bản trực tiếp (đã giải thực thể, gộp CDATA), chưa cắt khoảng trắng.
  String get chu => _chu.toString();

  /// Con đầu tiên có tên cục bộ [ten].
  NutXml? motCon(String ten) {
    for (final c in con) {
      if (c.tenCucBo == ten) return c;
    }
    return null;
  }

  /// Mọi hậu duệ (theo thứ tự tài liệu) có tên cục bộ [ten].
  Iterable<NutXml> hauDue(String ten) sync* {
    for (final c in con) {
      if (c.tenCucBo == ten) yield c;
      yield* c.hauDue(ten);
    }
  }

  /// Văn bản đã cắt của con [ten]; null nếu không có / rỗng.
  String? chuCon(String ten) {
    final t = motCon(ten)?.chu.trim();
    return t == null || t.isEmpty ? null : t;
  }
}

/// Giới hạn chống tệp độc: độ sâu lồng và số phần tử.
const _sauToiDa = 64;
const _nutToiDa = 500000;

/// Phân tích [s] -> phần tử gốc. Sai cú pháp -> [FormatException].
NutXml docXml(String s) {
  var i = 0;
  NutXml? goc;
  final ngan = <NutXml>[];
  var soNut = 0;

  Never loi(String m) => throw FormatException('xml: $m', s, i);

  int tim(String chuoi, int tu) {
    final k = s.indexOf(chuoi, tu);
    if (k < 0) loi('thiếu "$chuoi"');
    return k;
  }

  while (i < s.length) {
    final lt = s.indexOf('<', i);
    final het = lt < 0 ? s.length : lt;
    if (het > i) {
      final doan = s.substring(i, het);
      if (ngan.isEmpty) {
        if (doan.trim().isNotEmpty) loi('chữ ngoài phần tử gốc');
      } else {
        ngan.last._chu.write(giaiThucThe(doan));
      }
    }
    if (lt < 0) break;
    i = lt;
    if (s.startsWith('<?', i)) {
      i = tim('?>', i) + 2;
    } else if (s.startsWith('<!--', i)) {
      i = tim('-->', i) + 3;
    } else if (s.startsWith('<![CDATA[', i)) {
      final k = tim(']]>', i);
      if (ngan.isEmpty) loi('CDATA ngoài phần tử gốc');
      ngan.last._chu.write(s.substring(i + 9, k));
      i = k + 3;
    } else if (s.startsWith('<!', i)) {
      // DOCTYPE (có thể có [..] nội bộ): bỏ qua, không xử lý thực thể.
      final mo = s.indexOf('[', i);
      final dong = s.indexOf('>', i);
      if (dong < 0) loi('thiếu ">"');
      i = (mo >= 0 && mo < dong) ? tim(']>', mo) + 2 : dong + 1;
    } else if (s.startsWith('</', i)) {
      final k = tim('>', i);
      final ten = s.substring(i + 2, k).trim();
      if (ngan.isEmpty || ngan.last.ten != ten) loi('thẻ đóng lạ </$ten>');
      ngan.removeLast();
      i = k + 1;
    } else {
      final (nut, tuDong, sau) = _theMo(s, i + 1, loi);
      if (++soNut > _nutToiDa) loi('quá nhiều phần tử');
      if (ngan.isEmpty) {
        if (goc != null) loi('nhiều phần tử gốc');
        goc = nut;
      } else {
        ngan.last.con.add(nut);
      }
      if (!tuDong) {
        ngan.add(nut);
        if (ngan.length > _sauToiDa) loi('lồng quá sâu');
      }
      i = sau;
    }
  }
  if (goc == null) loi('không có phần tử');
  if (ngan.isNotEmpty) loi('thiếu thẻ đóng </${ngan.last.ten}>');
  return goc;
}

final _tenHopLe = RegExp(r'^[A-Za-z_][\w.\-:]*$');

(NutXml, bool, int) _theMo(String s, int i, Never Function(String) loi) {
  var k = i;
  while (k < s.length && !' \t\r\n/>'.contains(s[k])) {
    k++;
  }
  final ten = s.substring(i, k);
  if (!_tenHopLe.hasMatch(ten)) loi('tên thẻ lạ "$ten"');
  final tt = <String, String>{};
  while (true) {
    while (k < s.length && ' \t\r\n'.contains(s[k])) {
      k++;
    }
    if (k >= s.length) loi('thẻ <$ten> không đóng');
    if (s.startsWith('/>', k)) return (NutXml(ten, tt), true, k + 2);
    if (s[k] == '>') return (NutXml(ten, tt), false, k + 1);
    final bang = s.indexOf('=', k);
    if (bang < 0) loi('thuộc tính lạ');
    final ttTen = s.substring(k, bang).trim();
    if (!_tenHopLe.hasMatch(ttTen)) loi('tên thuộc tính lạ "$ttTen"');
    var q = bang + 1;
    while (q < s.length && ' \t\r\n'.contains(s[q])) {
      q++;
    }
    if (q >= s.length || (s[q] != '"' && s[q] != "'")) loi('thiếu nháy');
    final dong = s.indexOf(s[q], q + 1);
    if (dong < 0) loi('thiếu nháy đóng');
    tt[ttTen] = giaiThucThe(s.substring(q + 1, dong));
    k = dong + 1;
  }
}

final _thucThe = RegExp('&(#x[0-9A-Fa-f]+|#[0-9]+|lt|gt|amp|quot|apos);');

/// Giải 5 thực thể chuẩn + tham chiếu số; thực thể lạ giữ nguyên văn.
String giaiThucThe(String s) {
  if (!s.contains('&')) return s;
  return s.replaceAllMapped(_thucThe, (m) {
    final t = m[1]!;
    switch (t) {
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'amp':
        return '&';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
    }
    final ma = t.startsWith('#x')
        ? int.tryParse(t.substring(2), radix: 16)
        : int.tryParse(t.substring(1));
    if (ma == null || ma > 0x10FFFF || (ma >= 0xD800 && ma <= 0xDFFF)) {
      return m[0]!;
    }
    return String.fromCharCode(ma);
  });
}

final _kyTuCam = RegExp('[\x00-\x08\x0B\x0C\x0E-\x1F￾￿]');

/// Thoát chuỗi để ghi vào nội dung / thuộc tính XML; bỏ ký tự XML 1.0 cấm.
String thoatXml(String s) => s
    .replaceAll(_kyTuCam, '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Số thực -> chuỗi thập phân KHÔNG mũ (xsd:decimal), đọc lại ra đúng số cũ
/// (dựa trên `toString` ngắn nhất của Dart, chỉ dời dấu phẩy).
String soThapPhan(double x) {
  final s = x.toString();
  final e = s.indexOf('e');
  if (e < 0) return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  var dinh = s.substring(0, e);
  final mu = int.parse(s.substring(e + 1));
  final am = dinh.startsWith('-');
  if (am) dinh = dinh.substring(1);
  final cham = dinh.indexOf('.');
  final chuSo = dinh.replaceAll('.', '');
  // Vị trí dấu phẩy mới tính từ đầu dãy chữ số.
  final viTri = (cham < 0 ? dinh.length : cham) + mu;
  String kq;
  if (viTri <= 0) {
    kq = '0.${'0' * -viTri}$chuSo';
  } else if (viTri >= chuSo.length) {
    kq = chuSo + '0' * (viTri - chuSo.length);
  } else {
    kq = '${chuSo.substring(0, viTri)}.${chuSo.substring(viTri)}';
  }
  return am ? '-$kq' : kq;
}
