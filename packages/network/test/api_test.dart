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
          case '/lech':
            yc.response
              ..statusCode = 401
              ..headers.set('x-server-time', '1761800000000')
              ..write(jsonEncode({'status': 401, 'code': 'lech-gio'}));
          case '/tho':
            yc.response.write(
              jsonEncode({
                'than': than,
                'pt': yc.method,
                'ky': yc.headers.value('x-signature'),
              }),
            );
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

  test('gọi thô: đúng byte + header thêm; giờ server khi lệch', () async {
    final r = await api.goi(
      'POST',
      '/tho',
      than: utf8.encode('{"b":"á"}'),
      tieuDe: {'x-signature': 'abc'},
    );
    expect(r.duLieu, {'than': '{"b":"á"}', 'pt': 'POST', 'ky': 'abc'});
    expect(r.gioMayChu, isNull);
    final l = await api.get('/lech');
    expect((l.status, l.ma, l.gioMayChu), (401, 'lech-gio', 1761800000000));
  });

  group(
    'ghim CA (TLS thật, chứng chỉ tự ký sinh lúc chạy)',
    () {
      late Directory tam;
      late HttpServer tls;
      late String caPem;

      setUpAll(() async {
        tam = await Directory.systemTemp.createTemp('ghim');
        final kq = await Process.run('openssl', [
          'req',
          '-x509',
          '-newkey',
          'ec',
          '-pkeyopt',
          'ec_paramgen_curve:P-256',
          '-nodes',
          '-days',
          '2',
          '-subj',
          '/CN=127.0.0.1',
          '-addext',
          'subjectAltName=IP:127.0.0.1',
          '-keyout',
          '${tam.path}/k.pem',
          '-out',
          '${tam.path}/c.pem',
        ]);
        expect(kq.exitCode, 0, reason: '${kq.stderr}');
        caPem = File('${tam.path}/c.pem').readAsStringSync();
        final ctx = SecurityContext()
          ..useCertificateChain('${tam.path}/c.pem')
          ..usePrivateKey('${tam.path}/k.pem');
        tls = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx)
          ..listen((yc) async {
            yc.response.write('{"ok":true}');
            await yc.response.close();
          });
      });
      tearDownAll(() async {
        await tls.close(force: true);
        await tam.delete(recursive: true);
      });

      Uri goc() => Uri.parse('https://127.0.0.1:${tls.port}');

      test('CA nằm trong bộ ghim -> nối được', () async {
        final a = ApiClientIo(goc(), gocGhim: [caPem]);
        expect((await a.get('/')).duLieu, {'ok': true});
      });

      test(
        'bộ ghim mặc định (GTS / ISRG) -> LoiMang tls; xoay ghim -> nối được',
        () async {
          final a = ApiClientIo(goc(), gocGhim: gocMacDinh);
          await expectLater(
            a.get('/'),
            throwsA(isA<LoiMang>().having((e) => e.lyDo, 'lyDo', 'tls')),
          );
          a.doiGhim([...gocMacDinh, caPem]);
          expect((await a.get('/')).ok, isTrue);
          a.doiGhim(gocMacDinh);
          await expectLater(a.get('/'), throwsA(isA<LoiMang>()));
        },
      );

      test('kho CA hệ thống (không ghim) cũng không tin CA tự ký', () async {
        await expectLater(
          ApiClientIo(goc()).get('/'),
          throwsA(isA<LoiMang>().having((e) => e.lyDo, 'lyDo', 'tls')),
        );
      });
    },
    skip: Process.runSync('which', ['openssl']).exitCode == 0
        ? false
        : 'thiếu openssl',
  );

  test('giaiMaThan', () {
    expect(giaiMaThan([]), isNull);
    expect(giaiMaThan(utf8.encode('[1]')), isNull);
    expect(giaiMaThan(utf8.encode('{x')), isNull);
    expect(giaiMaThan(utf8.encode('{"a":true}')), {'a': true});
  });
}
