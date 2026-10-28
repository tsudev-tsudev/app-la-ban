import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:storage/src/domain/khoa_csdl.dart';
import 'package:storage/src/du_lieu/csdl.dart';

/// Tên tệp CSDL trong thư mục dữ liệu.
const tenTepCsdl = 'la_ban.db';

/// Kết quả mở CSDL. [csdl] null -> app chạy chế độ an toàn ([loi] cho biết vì
/// sao); dữ liệu trên đĩa KHÔNG bị đổi so với trước khi mở.
@immutable
final class KetQuaMoCsdl {
  const new({this.csdl, this.loi, this.lamMoiDoMatKhoa = false});

  final CsdlLaBan? csdl;

  /// `storage.migration` (đã khôi phục snapshot) · `storage.moiHon` (CSDL của
  /// bản app mới hơn) · `storage.mo` (lỗi khác).
  final Failure? loi;

  /// Tệp cũ không giải mã được bằng khoá hiện tại (mất khoá: cài lại, khôi
  /// phục máy) -> đã dời sang `.hong` và tạo CSDL mới.
  final bool lamMoiDoMatKhoa;
}

/// Hàm tạo CSDL từ executor - test thay để giả lập phiên bản schema mới.
typedef TaoCsdl = CsdlLaBan Function(QueryExecutor e);

/// Mở CSDL mã hoá ở [thuMuc] theo đúng thứ tự Spec §10.2: kiểm khoá -> đọc
/// `user_version` -> snapshot (bản sao tệp đã mã hoá) nếu sắp migrate ->
/// migrate trong transaction -> lỗi thì khôi phục snapshot.
Future<KetQuaMoCsdl> moCsdl({
  required String thuMuc,
  required Uint8List khoa,
  TaoCsdl? tao,
  bool nen = true,
}) async {
  final taoCsdl = tao ?? CsdlLaBan.new;
  final duongDan = '$thuMuc/$tenTepCsdl';
  final tep = File(duongDan);
  final cauKhoa = pragmaKhoa(khoa);

  void caiKhoa(Database db) {
    db
      ..execute(cauKhoa)
      ..execute('PRAGMA journal_mode = WAL');
  }

  // Drift mở tệp LƯỜI (ở truy vấn đầu) nên kiểm thô bên dưới chạy trước.
  final csdl = taoCsdl(
    nen
        ? NativeDatabase.createInBackground(tep, setup: caiKhoa)
        : NativeDatabase(tep, setup: caiKhoa),
  );
  final dich = csdl.schemaVersion;

  var lamMoi = false;
  File? snapshot;
  if (tep.existsSync()) {
    final v = _docPhienBan(duongDan, cauKhoa);
    if (v == null) {
      _doiSangHong(duongDan);
      lamMoi = true;
    } else if (v > dich) {
      await csdl.close();
      return KetQuaMoCsdl(
        loi: Failure('storage.moiHon', 'csdl v$v > app v$dich'),
      );
    } else if (v > 0 && v < dich) {
      snapshot = _chupSnapshot(duongDan, v);
    }
  }

  try {
    await csdl.customSelect('SELECT 1').get();
    return KetQuaMoCsdl(csdl: csdl, lamMoiDoMatKhoa: lamMoi);
  } on Object catch (e) {
    await csdl.close();
    if (snapshot != null) {
      _xoaKem(duongDan);
      snapshot.copySync(duongDan);
      return KetQuaMoCsdl(
        loi: Failure('storage.migration', e.runtimeType.toString()),
      );
    }
    return KetQuaMoCsdl(loi: Failure('storage.mo', e.runtimeType.toString()));
  }
}

/// `user_version` của tệp; null nếu khoá không mở được (không phải CSDL).
int? _docPhienBan(String duongDan, String cauKhoa) {
  final db = sqlite3.open(duongDan);
  try {
    db
      ..execute(cauKhoa)
      // Khoá sai: lệnh đọc ĐẦU TIÊN mới báo "file is not a database".
      ..select('SELECT count(*) FROM sqlite_master');
    final v = db.select('PRAGMA user_version').first.values.first! as int;
    // Gộp WAL vào tệp chính để bản sao tệp là đủ.
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    return v;
  } on SqliteException {
    return null;
  } finally {
    db.close();
  }
}

File _chupSnapshot(String duongDan, int v) {
  for (final cu in Directory(File(duongDan).parent.path).listSync()) {
    if (cu.path.contains('$tenTepCsdl.v') && cu.path.endsWith('.bak')) {
      cu.deleteSync();
    }
  }
  return File(duongDan).copySync('$duongDan.v$v.bak');
}

void _doiSangHong(String duongDan) {
  final hong = File('$duongDan.hong');
  if (hong.existsSync()) hong.deleteSync();
  File(duongDan).renameSync(hong.path);
  _xoaKem(duongDan);
}

void _xoaKem(String duongDan) {
  for (final duoi in ['-wal', '-shm', '-journal']) {
    final f = File('$duongDan$duoi');
    if (f.existsSync()) f.deleteSync();
  }
}
