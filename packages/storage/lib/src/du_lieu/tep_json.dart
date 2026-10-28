import 'dart:convert';
import 'dart:io';

/// Tệp JSON nhỏ ghi NGUYÊN TỬ (ghi tệp tạm + flush + rename) cho trạng thái
/// cần đọc trước khung đầu và phải sống khi CSDL lỗi: bộ đếm crash, cài đặt
/// giao diện, cờ tính năng. KHÔNG chứa dữ liệu nhạy cảm (nằm ở CSDL mã hoá).
final class TepJson {
  new _(this._tep, this._duLieu);

  /// Đọc đồng bộ (vài trăm byte - nhanh hơn mở CSDL). Tệp thiếu / hỏng -> rỗng.
  factory mo(String duongDan) {
    final tep = File(duongDan);
    var duLieu = <String, Object?>{};
    try {
      final j = jsonDecode(tep.readAsStringSync());
      if (j is Map<String, Object?>) duLieu = j;
    } on Object {
      // Thiếu hoặc hỏng: bắt đầu lại từ rỗng (giá trị mặc định an toàn).
    }
    return TepJson._(tep, duLieu);
  }

  final File _tep;
  Map<String, Object?> _duLieu;
  Future<void> _hang = Future.value();

  /// Nội dung hiện tại (chỉ đọc).
  Map<String, Object?> get duLieu => Map.unmodifiable(_duLieu);

  /// Ghi đồng bộ - dùng khi PHẢI bền trước bước kế (bộ đếm crash).
  void ghiDongBo(Map<String, Object?> moi) {
    _duLieu = Map.of(moi);
    File('${_tep.path}.tam')
      ..writeAsStringSync(jsonEncode(_duLieu), flush: true)
      ..renameSync(_tep.path);
  }

  /// Ghi bất đồng bộ, các lần ghi xếp hàng theo thứ tự gọi.
  Future<void> ghi(Map<String, Object?> moi) {
    _duLieu = Map.of(moi);
    final noiDung = jsonEncode(_duLieu);
    return _hang = _hang.then((_) async {
      final tam = File('${_tep.path}.tam');
      await tam.writeAsString(noiDung, flush: true);
      await tam.rename(_tep.path);
    });
  }
}
