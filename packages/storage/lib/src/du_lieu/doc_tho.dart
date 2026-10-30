import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:storage/src/domain/khoa_csdl.dart';
import 'package:storage/src/du_lieu/mo_csdl.dart';

/// Một dòng `diem` đọc thô - CHỈ các cột của schema v1 (bản nào cũng có,
/// migration chỉ thêm).
typedef DiemTho = ({
  String id,
  String ten,
  double viDo,
  double kinhDo,
  double? caoDo,
  String ghiChu,
  int taoLuc,
  int suaLuc,
});

/// Đọc điểm thẳng bằng `sqlite3` khi Drift không mở được CSDL (chế độ an
/// toàn - Spec §10.4 "cho phép xuất dữ liệu waypoint"). Không migrate, không
/// tạo tệp; chỉ SELECT. Tệp không có / khoá sai / không có bảng -> ném
/// [SqliteException] hoặc [StateError].
List<DiemTho> docDiemTho({required String thuMuc, required Uint8List khoa}) {
  // readWrite (không create): CSDL ở chế độ WAL cần ghi tệp -shm để đọc.
  final db = sqlite3.open(
    '$thuMuc/$tenTepCsdl',
    mode: OpenMode.readWrite,
  );
  try {
    db.execute(pragmaKhoa(khoa));
    final kq = db.select(
      'SELECT id, ten, vi_do, kinh_do, cao_do, ghi_chu, tao_luc, sua_luc '
      'FROM diem ORDER BY tao_luc, id',
    );
    return [
      for (final d in kq)
        (
          id: d['id'] as String,
          ten: d['ten'] as String,
          viDo: (d['vi_do'] as num).toDouble(),
          kinhDo: (d['kinh_do'] as num).toDouble(),
          caoDo: (d['cao_do'] as num?)?.toDouble(),
          ghiChu: d['ghi_chu'] as String,
          taoLuc: d['tao_luc'] as int,
          suaLuc: d['sua_luc'] as int,
        ),
    ];
  } finally {
    db.close();
  }
}
