import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

void main() {
  late Directory tm;
  setUp(() => tm = Directory.systemTemp.createTempSync('tep_json'));
  tearDown(() => tm.deleteSync(recursive: true));

  test('thiếu tệp -> rỗng; ghi đồng bộ đọc lại được', () {
    final t = TepJson.mo('${tm.path}/a.json');
    expect(t.duLieu, isEmpty);
    t.ghiDongBo({'x': 1});
    expect(TepJson.mo('${tm.path}/a.json').duLieu, {'x': 1});
    expect(File('${tm.path}/a.json.tam').existsSync(), isFalse);
  });

  test('tệp hỏng / không phải object -> rỗng', () {
    File('${tm.path}/b.json').writeAsStringSync('{hỏng');
    expect(TepJson.mo('${tm.path}/b.json').duLieu, isEmpty);
    File('${tm.path}/c.json').writeAsStringSync('[1]');
    expect(TepJson.mo('${tm.path}/c.json').duLieu, isEmpty);
  });

  test('ghi bất đồng bộ theo thứ tự, lần cuối thắng', () async {
    final t = TepJson.mo('${tm.path}/d.json');
    final a = t.ghi({'v': 1});
    final b = t.ghi({'v': 2});
    expect(t.duLieu, {'v': 2});
    await Future.wait([a, b]);
    expect(TepJson.mo('${tm.path}/d.json').duLieu, {'v': 2});
  });

  test('duLieu chỉ đọc', () {
    final t = TepJson.mo('${tm.path}/e.json');
    expect(() => t.duLieu['x'] = 1, throwsUnsupportedError);
  });
}
