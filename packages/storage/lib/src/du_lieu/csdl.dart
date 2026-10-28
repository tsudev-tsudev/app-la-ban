import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:storage/src/domain/ke_hoach_migration.dart';

part 'csdl.g.dart';

/// Điểm đánh dấu (waypoint). Mở rộng ở A6 bằng migration CHỈ THÊM.
@DataClassName('DongDiem')
class Diem extends Table {
  TextColumn get id => text()();
  TextColumn get ten => text().withLength(min: 1, max: 120)();
  // Mẫu CHECK của drift: getter tham chiếu chính cột.
  // ignore: recursive_getters
  RealColumn get viDo => real().check(viDo.isBetweenValues(-90, 90))();
  // Như trên: mẫu CHECK của drift.
  // ignore: recursive_getters
  RealColumn get kinhDo => real().check(kinhDo.isBetweenValues(-180, 180))();
  RealColumn get caoDo => real().nullable()();
  TextColumn get ghiChu => text().withDefault(const Constant(''))();

  /// Mốc thời gian UTC, mili giây.
  IntColumn get taoLuc => integer()();
  IntColumn get suaLuc => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Nhật ký migration đã chạy trên máy (báo lỗi về server ở S5).
@DataClassName('DongLichSuMigration')
class LichSuMigration extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tu => integer()();
  IntColumn get den => integer()();
  IntColumn get luc => integer()();
}

/// Một bước migration lên đúng phiên bản `v` (chạy trong transaction chung).
/// Bước PHẢI idempotent và chỉ mở rộng (QUYET_DINH / CLAUDE.md: expand ->
/// contract qua 2 bản phát hành).
typedef BuocMigration = Future<void> Function(Migrator m, CsdlLaBan db);

/// Các bước của bản phát hành. Thêm phiên bản: tăng `schemaVersion` (số
/// trực tiếp - drift_dev đọc literal), thêm `v: (m, db) async {...}`, chạy
/// `dart run drift_dev make-migrations` rồi `build_runner build`.
final Map<int, BuocMigration> buocMigration = {};

@DriftDatabase(tables: [Diem, LichSuMigration])
class CsdlLaBan extends _$CsdlLaBan {
  new(super.e, {@visibleForTesting Map<int, BuocMigration>? buoc})
    : _buoc = buoc ?? buocMigration;

  final Map<int, BuocMigration> _buoc;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, tu, den) async {
      final ds = keHoachMigration(tu: tu, den: den, coBuoc: _buoc.keys.toSet());
      // Một transaction cho cả chuỗi: lỗi giữa chừng -> SQLite cuộn lại hết
      // (DDL cũng trong transaction); snapshot tệp là lớp bảo vệ thứ hai.
      await transaction(() async {
        for (final v in ds) {
          await _buoc[v]!(m, this);
        }
        await into(lichSuMigration).insert(
          LichSuMigrationCompanion.insert(
            tu: tu,
            den: den,
            luc: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
      });
    },
    beforeOpen: (chiTiet) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (chiTiet.hadUpgrade) {
        final kq = await customSelect('PRAGMA quick_check').getSingle();
        if (kq.data.values.first != 'ok') {
          throw StateError('csdl.quickCheck: ${kq.data.values.first}');
        }
      }
    },
  );
}
