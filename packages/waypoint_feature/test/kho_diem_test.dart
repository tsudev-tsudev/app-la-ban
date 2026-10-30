import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

import 'thu_chung.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  for (final (ten, tao) in <(String, KhoDiem Function())>[
    ('Drift', () => KhoDiemDrift(CsdlLaBan(NativeDatabase.memory()))),
    ('bộ nhớ', KhoDiemBoNho.new),
  ]) {
    group('KhoDiem $ten', () {
      test('lưu / cập nhật / xoá; mới tạo trước; ảnh giữ khi sửa điểm, đi '
          'theo khi xoá', () async {
        final kho = tao();
        final luong = kho.theoDoi();
        await kho.luuNhieu(diemThu);
        expect((await kho.tatCa()).map((d) => d.id), ['a', 'b']);
        await kho.themAnh('a', (
          duLieu: Uint8List.fromList([1, 2]),
          rong: 2,
          cao: 1,
        ), luc: 1);
        await kho.luu(diemThu[0].copyWith(ten: 'Mới', suaLuc: gioThu + 1));
        expect((await kho.tatCa()).first.ten, 'Mới');
        final anh = await kho.theoDoiAnh('a').first;
        expect(anh.single.duLieu, [1, 2]);
        await kho.xoaAnh(anh.single.id);
        expect(await kho.theoDoiAnh('a').first, isEmpty);
        await kho.themAnh('a', (
          duLieu: Uint8List.fromList([3]),
          rong: 1,
          cao: 1,
        ), luc: 2);
        await kho.xoa('a');
        expect((await kho.tatCa()).map((d) => d.id), ['b']);
        expect(await kho.theoDoiAnh('a').first, isEmpty);
        expect(await luong.first, isA<List<DiemMoc>>());
      });
    });
  }
}
