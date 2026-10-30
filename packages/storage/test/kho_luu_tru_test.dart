import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

class KhoLoi implements KhoKhoa {
  new(this.thuMuc);

  final String thuMuc;

  @override
  Future<Uint8List> layKhoaCsdl() => throw StateError('keystore');

  @override
  Future<String> thuMucDuLieu() async => thuMuc;
}

void main() {
  late Directory tm;
  setUp(() => tm = Directory.systemTemp.createTempSync('kho'));
  tearDown(() => tm.deleteSync(recursive: true));

  Future<KhoLuuTru> mo(KhoKhoa k, [String pb = '1.0.0']) =>
      KhoLuuTru.mo(phienBanApp: pb, khoKhoa: k, nen: false);

  test('chạy thường: CSDL mở, không an toàn, cờ mặc định', () async {
    final kho = await mo(KhoKhoaBoNho(tm.path));
    addTearDown(kho.dong);
    expect(kho.anToan, isNull);
    expect(kho.csdl, isNotNull);
    expect(kho.thuMuc, tm.path);
    expect(kho.coCucBo, isEmpty);
    await kho.datCoCucBo({CoTinhNang.ar: false});
    expect(kho.coCucBo, {CoTinhNang.ar: false});
    await kho.caiDat.ghi({'cheDo': 'toi'});
    expect(TepJson.mo('${tm.path}/cai_dat.json').duLieu, {'cheDo': 'toi'});
  });

  test('chế độ an toàn (crash): CSDL không mở nhưng vẫn đọc thô được điểm '
      'để xuất', () async {
    final k = KhoKhoaBoNho(tm.path);
    var kho = await mo(k);
    final db = kho.csdl!;
    await db
        .into(db.diem)
        .insert(
          DiemCompanion.insert(
            id: 'a',
            ten: 'Đỉnh Fansipan',
            viDo: 22.303889,
            kinhDo: 103.775,
            caoDo: const Value(3143.2),
            taoLuc: 1,
            suaLuc: 2,
          ),
        );
    await kho.dong();
    for (var i = 0; i < 3; i++) {
      kho = await mo(k);
    }
    kho = await mo(k);
    expect(kho.anToan, LyDoAnToan.crashLienTiep);
    expect(kho.csdl, isNull);
    final ds = await kho.docDiemAnToan();
    expect(ds.single, (
      id: 'a',
      ten: 'Đỉnh Fansipan',
      viDo: 22.303889,
      kinhDo: 103.775,
      caoDo: 3143.2,
      ghiChu: '',
      taoLuc: 1,
      suaLuc: 2,
    ));
  });

  test('đọc thô: khoá sai -> ném lỗi, không tạo tệp mới', () {
    expect(
      () => docDiemTho(thuMuc: tm.path, khoa: Uint8List(32)),
      throwsA(anything),
    );
    expect(File('${tm.path}/$tenTepCsdl').existsSync(), isFalse);
  });

  test('3 lần crash trước khi ổn định -> lần 4 an toàn, không mở CSDL; '
      'ổn định không bỏ ghim; thoát an toàn thì lần sau thường', () async {
    final k = KhoKhoaBoNho(tm.path);
    for (var i = 0; i < 3; i++) {
      final kho = await mo(k);
      expect(kho.anToan, isNull);
      await kho.dong();
    }
    var kho = await mo(k);
    expect(kho.anToan, LyDoAnToan.crashLienTiep);
    expect(kho.csdl, isNull);
    kho.danhDauOnDinh();
    kho = await mo(k);
    expect(kho.anToan, LyDoAnToan.crashLienTiep);
    kho.thoatCheDoAnToan();
    kho = await mo(k);
    expect(kho.anToan, isNull);
    kho.danhDauOnDinh();
    await kho.dong();
  });

  test('lên bản mới gỡ ghim an toàn', () async {
    final k = KhoKhoaBoNho(tm.path);
    for (var i = 0; i < 4; i++) {
      await (await mo(k)).dong();
    }
    final kho = await mo(k, '1.0.1');
    expect(kho.anToan, isNull);
    await kho.dong();
  });

  test('keystore lỗi -> an toàn do lỗi lưu trữ, app vẫn chạy', () async {
    final kho = await mo(KhoLoi(tm.path));
    expect(kho.csdl, isNull);
    expect(kho.ketQuaCsdl.loi?.code, 'storage.khoa');
    expect(kho.anToan, LyDoAnToan.migrationLoi);
  });

  test('CSDL mới hơn -> an toàn csdlMoiHon', () async {
    final k = KhoKhoaBoNho(tm.path);
    final kho = await mo(k);
    await kho.csdl!.customStatement('PRAGMA user_version = 9');
    await kho.dong();
    final lai = await mo(k);
    expect(lai.anToan, LyDoAnToan.csdlMoiHon);
  });
}
