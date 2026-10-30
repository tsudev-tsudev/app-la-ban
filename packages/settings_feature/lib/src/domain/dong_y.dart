import 'package:meta/meta.dart';

/// Phiên bản thông báo xử lý dữ liệu (NĐ 13/2023) đang hiển thị. Đổi nội dung
/// thông báo (thêm loại dữ liệu, bên nhận, mục đích) -> tăng số này -> mọi
/// người dùng được hỏi lại ở lần mở app sau.
const banThongBaoDuLieu = 1;

/// Lựa chọn của người dùng với thông báo xử lý dữ liệu (QUYET_DINH Q43).
/// [trucTuyen] = đồng ý gửi dữ liệu bảo mật kỹ thuật (đăng ký thiết bị, sự
/// kiện RASP, cấu hình từ xa); false = chỉ dùng ngoại tuyến.
@immutable
final class DongYXuLy {
  const new({required this.ban, required this.trucTuyen, required this.luc});

  /// Đọc từ JSON đã lưu; hỏng / thiếu trường -> null (coi như chưa trả lời).
  static DongYXuLy? tuJson(Object? j) {
    if (j is! Map) return null;
    final ban = j['ban'];
    final trucTuyen = j['trucTuyen'];
    final luc = switch (j['luc']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    };
    if (ban is! int || trucTuyen is! bool || luc == null) return null;
    return DongYXuLy(ban: ban, trucTuyen: trucTuyen, luc: luc);
  }

  Map<String, Object?> toJson() => {
    'ban': ban,
    'trucTuyen': trucTuyen,
    'luc': luc.toUtc().toIso8601String(),
  };

  /// Phiên bản thông báo người dùng đã xem khi chọn.
  final int ban;

  final bool trucTuyen;

  /// Thời điểm chọn (bằng chứng đồng ý - NĐ 13/2023 Điều 11).
  final DateTime luc;

  @override
  bool operator ==(Object other) =>
      other is DongYXuLy &&
      other.ban == ban &&
      other.trucTuyen == trucTuyen &&
      other.luc.isAtSameMomentAs(luc);

  @override
  int get hashCode => Object.hash(ban, trucTuyen, luc.microsecondsSinceEpoch);

  @override
  String toString() =>
      'DongYXuLy(ban: $ban, trucTuyen: $trucTuyen, luc: ${toJson()['luc']})';
}

/// Cần hiện thông báo xử lý dữ liệu: chưa trả lời, hoặc đã trả lời cho bản
/// thông báo cũ hơn.
bool canHoiDongY(DongYXuLy? d) => d == null || d.ban < banThongBaoDuLieu;

/// Được gửi dữ liệu lên máy chủ: chỉ khi đã đồng ý ĐÚNG bản thông báo hiện
/// hành (bản cũ chưa trả lời lại -> tạm dừng, không suy diễn đồng ý).
bool choPhepTrucTuyen(DongYXuLy? d) =>
    d != null && d.ban >= banThongBaoDuLieu && d.trucTuyen;

/// Trang Chính sách quyền riêng tư đầy đủ theo ngôn ngữ đang hiển thị.
Uri urlChinhSach(String maNgonNgu) => Uri.parse(
  maNgonNgu == 'vi'
      ? 'https://compass.tsudev.com/quyen-rieng-tu/'
      : 'https://compass.tsudev.com/en/privacy/',
);
