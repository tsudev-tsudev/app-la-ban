import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:storage/storage.dart';

/// Giả lập bản app có schema v2 (bản phát hành thật thêm bước vào
/// `buocMigration` và tăng `schemaVersion`).
class CsdlV2 extends CsdlLaBan {
  new(super.e, {super.buoc});

  @override
  int get schemaVersion => 2;
}

const soDiem = 10000;

final khoa = Uint8List.fromList(List.generate(32, (i) => 255 - i));

Future<void> themDiem(CsdlLaBan db, int n) => db.batch((b) {
  b.insertAll(db.diem, [
    for (var i = 0; i < n; i++)
      DiemCompanion.insert(
        id: 'd${i.toString().padLeft(5, '0')}',
        ten: 'Điểm $i',
        viDo: -90 + (i * 0.017) % 180,
        kinhDo: -180 + (i * 0.031) % 360,
        caoDo: Value(i.isEven ? null : i / 7),
        ghiChu: Value(i % 3 == 0 ? 'ghi chú ✓ $i' : ''),
        taoLuc: 1700000000000 + i,
        suaLuc: 1700000000000 + i * 2,
      ),
  ]);
});

/// Tổng kiểm các cột v1 của bảng diem (thứ tự theo id).
Future<String> tongKiemDiem(CsdlLaBan db) async {
  final dong = await db
      .customSelect(
        'SELECT id, ten, vi_do, kinh_do, cao_do, ghi_chu, tao_luc, sua_luc '
        'FROM diem ORDER BY id',
      )
      .get();
  return tongKiem(dong.map((d) => d.data.values.toList()));
}

void main() {
  // Test cố ý mở nhiều lần (mỗi lần đóng trước khi mở lại).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tm;
  late String tep;
  setUp(() {
    tm = Directory.systemTemp.createTempSync('mo_csdl');
    tep = '${tm.path}/$tenTepCsdl';
  });
  tearDown(() => tm.deleteSync(recursive: true));

  Future<CsdlLaBan> moV1() async {
    final kq = await moCsdl(thuMuc: tm.path, khoa: khoa, nen: false);
    expect(kq.loi, isNull);
    return kq.csdl!;
  }

  test('tệp trên đĩa được mã hoá; sai khoá không đọc được', () async {
    final db = await moV1();
    await themDiem(db, 10);
    await db.close();
    final dau = File(tep).readAsBytesSync().sublist(0, 16);
    expect(String.fromCharCodes(dau), isNot(startsWith('SQLite format 3')));
    final tho = sqlite3.open(tep);
    addTearDown(tho.close);
    expect(
      () => tho.select('SELECT count(*) FROM sqlite_master'),
      throwsA(isA<SqliteException>()),
    );
  });

  test('mở lại giữ nguyên dữ liệu, không tạo snapshot', () async {
    var db = await moV1();
    await themDiem(db, 100);
    final truoc = await tongKiemDiem(db);
    await db.close();
    db = await moV1();
    expect(await tongKiemDiem(db), truoc);
    await db.close();
    expect(File('$tep.v1.bak').existsSync(), isFalse);
  });

  test('mở trong isolate nền', () async {
    final kq = await moCsdl(thuMuc: tm.path, khoa: khoa);
    final db = kq.csdl!;
    expect(await db.select(db.diem).get(), isEmpty);
    await db.close();
  });

  test('mất khoá -> dời tệp sang .hong, tạo CSDL mới', () async {
    final db = await moV1();
    await themDiem(db, 5);
    await db.close();
    File('$tep.hong').writeAsStringSync('cũ');
    final khac = Uint8List.fromList(List.filled(32, 7));
    final kq = await moCsdl(thuMuc: tm.path, khoa: khac, nen: false);
    expect(kq.lamMoiDoMatKhoa, isTrue);
    expect(await kq.csdl!.select(kq.csdl!.diem).get(), isEmpty);
    await kq.csdl!.close();
    expect(File('$tep.hong').lengthSync(), greaterThan(100));
  });

  group('migration v1 -> v2 với $soDiem điểm', () {
    test('thành công: dữ liệu không đổi (checksum), có snapshot, '
        'ghi lịch sử', () async {
      var db = await moV1();
      await themDiem(db, soDiem);
      final truoc = await tongKiemDiem(db);
      await db.close();

      final kq = await moCsdl(
        thuMuc: tm.path,
        khoa: khoa,
        nen: false,
        tao: (e) => CsdlV2(
          e,
          buoc: {
            2: (m, db) => db.customStatement(
              "ALTER TABLE diem ADD COLUMN mau TEXT NOT NULL DEFAULT ''",
            ),
          },
        ),
      );
      expect(kq.loi, isNull);
      db = kq.csdl!;
      expect(await tongKiemDiem(db), truoc);
      final ls = await db.select(db.lichSuMigration).getSingle();
      expect((ls.tu, ls.den), (1, 2));
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.data.values.first, 2);
      await db.close();
      expect(File('$tep.v1.bak').existsSync(), isTrue);
    });

    test('lỗi giữa chừng: khôi phục snapshot, dữ liệu v1 nguyên vẹn', () async {
      var db = await moV1();
      await themDiem(db, soDiem);
      final truoc = await tongKiemDiem(db);
      await db.close();
      // Snapshot cũ của lần trước bị dọn.
      File('$tep.v0.bak').writeAsStringSync('cũ');

      final kq = await moCsdl(
        thuMuc: tm.path,
        khoa: khoa,
        nen: false,
        tao: (e) => CsdlV2(
          e,
          buoc: {
            2: (m, db) async {
              await db.customStatement('ALTER TABLE diem ADD COLUMN mau TEXT');
              await db.customStatement('DELETE FROM diem');
              throw StateError('bước lỗi');
            },
          },
        ),
      );
      expect(kq.csdl, isNull);
      expect(kq.loi?.code, 'storage.migration');
      expect(File('$tep.v0.bak').existsSync(), isFalse);

      db = await moV1();
      expect(await tongKiemDiem(db), truoc);
      final cot = await db.customSelect('PRAGMA table_info(diem)').get();
      expect(cot.map((c) => c.data['name']), isNot(contains('mau')));
      await db.close();
    });

    test('thiếu bước migration -> lỗi, dữ liệu giữ nguyên', () async {
      final db = await moV1();
      await themDiem(db, 3);
      await db.close();
      final kq = await moCsdl(
        thuMuc: tm.path,
        khoa: khoa,
        nen: false,
        tao: (e) => CsdlV2(e, buoc: {}),
      );
      expect(kq.loi?.code, 'storage.migration');
      final lai = await moV1();
      expect(await lai.select(lai.diem).get(), hasLength(3));
      await lai.close();
    });
  });

  test('CSDL của bản mới hơn -> không mở, không đụng tệp', () async {
    final v2 = await moCsdl(
      thuMuc: tm.path,
      khoa: khoa,
      nen: false,
      tao: (e) => CsdlV2(e, buoc: {}),
    );
    await v2.csdl!.close();
    final byte = File(tep).readAsBytesSync();
    final kq = await moCsdl(thuMuc: tm.path, khoa: khoa, nen: false);
    expect(kq.csdl, isNull);
    expect(kq.loi?.code, 'storage.moiHon');
    expect(File(tep).readAsBytesSync(), byte);
  });

  test('lỗi mở không do migration -> storage.mo', () async {
    Directory(tep).createSync();
    final kq = await moCsdl(thuMuc: tm.path, khoa: khoa, nen: false);
    expect(kq.loi?.code, 'storage.mo');
  });

  test('ràng buộc vĩ độ / kinh độ', () async {
    final db = await moV1();
    addTearDown(db.close);
    await expectLater(
      db
          .into(db.diem)
          .insert(
            DiemCompanion.insert(
              id: 'x',
              ten: 'x',
              viDo: 91,
              kinhDo: 0,
              taoLuc: 0,
              suaLuc: 0,
            ),
          ),
      throwsA(anything),
    );
  });
}
