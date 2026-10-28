import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

void main() {
  group('tongKiem', () {
    test('ổn định và phân biệt kiểu', () {
      final a = tongKiem([
        [
          1,
          'a',
          null,
          1.5,
          Uint8List.fromList([1, 2]),
        ],
      ]);
      expect(a, hasLength(16));
      expect(
        tongKiem([
          [
            1,
            'a',
            null,
            1.5,
            Uint8List.fromList([1, 2]),
          ],
        ]),
        a,
      );
      expect(
        tongKiem([
          [1],
        ]),
        isNot(
          tongKiem([
            [1.0],
          ]),
        ),
      );
      expect(
        tongKiem([
          [1],
        ]),
        isNot(
          tongKiem([
            ['1'],
          ]),
        ),
      );
      expect(
        tongKiem([
          [null],
        ]),
        isNot(
          tongKiem([
            [''],
          ]),
        ),
      );
      // Ranh giới dòng / cột không trộn được.
      expect(
        tongKiem([
          ['ab'],
        ]),
        isNot(
          tongKiem([
            ['a', 'b'],
          ]),
        ),
      );
      expect(
        tongKiem([
          ['a'],
          ['b'],
        ]),
        isNot(
          tongKiem([
            ['a', 'b'],
          ]),
        ),
      );
      expect(tongKiem(const []), 'cbf29ce484222325');
    });

    test('kiểu lạ -> ArgumentError', () {
      expect(
        () => tongKiem([
          [true],
        ]),
        throwsArgumentError,
      );
    });
  });

  group('keHoachMigration', () {
    test('liệt kê bước liên tiếp', () {
      expect(keHoachMigration(tu: 1, den: 3, coBuoc: {2, 3, 4}), [2, 3]);
      expect(keHoachMigration(tu: 3, den: 3, coBuoc: {}), isEmpty);
    });

    test('thiếu bước hoặc hạ cấp -> StateError', () {
      expect(
        () => keHoachMigration(tu: 1, den: 3, coBuoc: {3}),
        throwsA(
          isA<StateError>().having((e) => e.message, 'm', contains('[2]')),
        ),
      );
      expect(
        () => keHoachMigration(tu: 4, den: 3, coBuoc: {}),
        throwsStateError,
      );
    });
  });

  group('pragmaKhoa', () {
    test('khoá thô hex 64 ký tự', () {
      final k = Uint8List.fromList(List.generate(32, (i) => i));
      const hex =
          '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
      expect(pragmaKhoa(k), 'PRAGMA key = "x\'$hex\'"');
    });

    test('sai độ dài -> ArgumentError', () {
      expect(() => pragmaKhoa(Uint8List(16)), throwsArgumentError);
    });
  });
}
