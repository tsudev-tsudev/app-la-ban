import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kenh = MethodChannel('la_ban/luu_tru');
  final may = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void gia(Object? Function(MethodCall c) xuLy) {
    may.setMockMethodCallHandler(kenh, (c) async => xuLy(c));
    addTearDown(() => may.setMockMethodCallHandler(kenh, null));
  }

  test('KhoKhoaNenTang gọi đúng phương thức', () async {
    gia(
      (c) => switch (c.method) {
        'layKhoaCsdl' => Uint8List(32),
        'thuMucDuLieu' => '/du-lieu',
        _ => null,
      },
    );
    const k = KhoKhoaNenTang();
    expect(await k.layKhoaCsdl(), hasLength(32));
    expect(await k.thuMucDuLieu(), '/du-lieu');
  });

  test('KhoKhoaNenTang từ chối khoá sai độ dài / thư mục rỗng', () async {
    gia((c) => c.method == 'layKhoaCsdl' ? Uint8List(16) : '');
    const k = KhoKhoaNenTang();
    await expectLater(k.layKhoaCsdl(), throwsA(isA<PlatformException>()));
    await expectLater(k.thuMucDuLieu(), throwsA(isA<PlatformException>()));
  });

  test('KhoKhoaBoNho sinh một lần, giữ nguyên', () async {
    final k = KhoKhoaBoNho('/t');
    final a = await k.layKhoaCsdl();
    expect(a, hasLength(32));
    expect(await k.layKhoaCsdl(), same(a));
    expect(await k.thuMucDuLieu(), '/t');
  });
}
