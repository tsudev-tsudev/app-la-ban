import 'dart:convert';
import 'dart:io';

import 'package:network/network.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer may;
  late ApiClientIo api;

  setUp(() async {
    may = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((yc) async {
        final than = await utf8.decodeStream(yc);
        yc.response.headers.contentType = ContentType.json;
        switch (yc.uri.path) {
          case '/vang':
            yc.response.write(
              jsonEncode({
                'than': than,
                'auth': yc.headers.value('authorization'),
                'loai': yc.headers.contentType?.mimeType,
              }),
            );
          case '/loi':
            yc.response
              ..statusCode = 401
              ..write(jsonEncode({'status': 401, 'code': 'token-sai'}));
          case '/cham':
            await Future<void>.delayed(const Duration(seconds: 2));
          default:
            yc.response.statusCode = 404;
        }
        await yc.response.close();
      });
    api = ApiClientIo(
      Uri.parse('http://127.0.0.1:${may.port}'),
      hetGio: const Duration(milliseconds: 500),
    );
  });
  tearDown(() => may.close(force: true));

  test('POST JSON + Bearer', () async {
    final r = await api.post('/vang', {'a': 1}, bearer: 'tok');
    expect(r.ok, isTrue);
    expect(r.duLieu, {
      'than': '{"a":1}',
      'auth': 'Bearer tok',
      'loai': 'application/json',
    });
  });

  test('lỗi RFC 7807 -> mã', () async {
    final r = await api.get('/loi');
    expect(r.status, 401);
    expect(r.ma, 'token-sai');
  });

  test('hết giờ / không kết nối -> LoiMang', () async {
    await expectLater(api.get('/cham'), throwsA(isA<LoiMang>()));
    final chet = ApiClientIo(Uri.parse('http://127.0.0.1:1'));
    await expectLater(chet.get('/x'), throwsA(isA<LoiMang>()));
  });

  test('giaiMaThan', () {
    expect(giaiMaThan([]), isNull);
    expect(giaiMaThan(utf8.encode('[1]')), isNull);
    expect(giaiMaThan(utf8.encode('{x')), isNull);
    expect(giaiMaThan(utf8.encode('{"a":true}')), {'a': true});
  });
}
