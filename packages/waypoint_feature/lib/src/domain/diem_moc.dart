import 'dart:math';

import 'package:meta/meta.dart';

/// Độ dài tối đa của tên điểm (khớp ràng buộc cột `diem.ten`).
const tenToiDa = 120;

/// Độ dài tối đa của ghi chú.
const ghiChuToiDa = 2000;

/// Điểm mốc (waypoint) - WGS84, độ; cao độ mét trên mực biển.
@immutable
final class DiemMoc {
  const new({
    required this.id,
    required this.ten,
    required this.viDo,
    required this.kinhDo,
    required this.taoLuc,
    required this.suaLuc,
    this.caoDo,
    this.ghiChu = '',
  });

  final String id;
  final String ten;
  final double viDo;
  final double kinhDo;
  final double? caoDo;
  final String ghiChu;

  /// Mốc thời gian UTC, mili giây.
  final int taoLuc;
  final int suaLuc;

  DiemMoc copyWith({
    String? ten,
    double? viDo,
    double? kinhDo,
    double? Function()? caoDo,
    String? ghiChu,
    int? suaLuc,
  }) => DiemMoc(
    id: id,
    ten: ten ?? this.ten,
    viDo: viDo ?? this.viDo,
    kinhDo: kinhDo ?? this.kinhDo,
    caoDo: caoDo == null ? this.caoDo : caoDo(),
    ghiChu: ghiChu ?? this.ghiChu,
    taoLuc: taoLuc,
    suaLuc: suaLuc ?? this.suaLuc,
  );

  @override
  bool operator ==(Object other) =>
      other is DiemMoc &&
      other.id == id &&
      other.ten == ten &&
      other.viDo == viDo &&
      other.kinhDo == kinhDo &&
      other.caoDo == caoDo &&
      other.ghiChu == ghiChu &&
      other.taoLuc == taoLuc &&
      other.suaLuc == suaLuc;

  @override
  int get hashCode =>
      Object.hash(id, ten, viDo, kinhDo, caoDo, ghiChu, taoLuc, suaLuc);

  @override
  String toString() => 'DiemMoc($id, $ten, $viDo, $kinhDo, $caoDo)';
}

/// Lỗi dữ liệu điểm (giao diện đổi sang chuỗi i18n).
enum LoiDiem { tenTrong, tenDai, viDo, kinhDo, caoDo, ghiChuDai }

/// Kiểm điểm trước khi lưu; rỗng = hợp lệ.
Set<LoiDiem> kiemDiem({
  required String ten,
  required double? viDo,
  required double? kinhDo,
  double? caoDo,
  String ghiChu = '',
}) => {
  if (ten.trim().isEmpty) LoiDiem.tenTrong,
  if (ten.trim().length > tenToiDa) LoiDiem.tenDai,
  if (viDo == null || !viDo.isFinite || viDo.abs() > 90) LoiDiem.viDo,
  if (kinhDo == null || !kinhDo.isFinite || kinhDo.abs() > 180) LoiDiem.kinhDo,
  // Đáy Mariana -> độ cao bay dân dụng có dư.
  if (caoDo != null && (!caoDo.isFinite || caoDo < -12000 || caoDo > 20000))
    LoiDiem.caoDo,
  if (ghiChu.length > ghiChuToiDa) LoiDiem.ghiChuDai,
};

/// Cắt chuỗi về tối đa [n] ký tự (rune, không cắt đôi ký tự ngoài BMP).
String catChuoi(String s, int n) {
  final r = s.runes;
  return r.length <= n ? s : String.fromCharCodes(r.take(n));
}

/// Mã điểm ngẫu nhiên dạng UUID v4 (không gắn với thiết bị / người dùng).
String taoIdDiem([Random? rng]) {
  final r = rng ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
