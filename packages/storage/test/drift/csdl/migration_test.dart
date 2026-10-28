// Ma trận migration (Spec §10.2): mọi phiên bản schema đã chụp ở
// drift_schemas/ -> phiên bản hiện tại, so schema thực với ảnh chụp.
// Thêm phiên bản: `dart run drift_dev make-migrations` rồi
// `dart run drift_dev schema generate drift_schemas/csdl/ test/drift/csdl/generated/`.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

import 'generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  // Drift mở lười: chỉ đọc schemaVersion, không chạm executor.
  final hienTai = CsdlLaBan(NativeDatabase.memory()).schemaVersion;

  test('schema mã nguồn khớp ảnh chụp v$hienTai (đổi bảng phải tăng '
      'phiên bản + make-migrations)', () {
    expect(GeneratedHelper.versions.last, hienTai);
  });

  for (final tu in GeneratedHelper.versions) {
    test('v$tu -> v$hienTai: schema đúng ảnh chụp', () async {
      final ket = await verifier.schemaAt(tu);
      final db = CsdlLaBan(ket.newConnection());
      await verifier.migrateAndValidate(db, hienTai);
      await db.close();
    });
  }
}
