import 'package:meta/meta.dart';

/// Vì sao app đang ở chế độ an toàn (Spec §10.4).
enum LyDoAnToan {
  /// [nguongCrash] lần khởi động liên tiếp không tới trạng thái ổn định.
  crashLienTiep,

  /// Migration CSDL lỗi, đã khôi phục snapshot - dữ liệu cũ còn nguyên.
  migrationLoi,

  /// CSDL do bản app MỚI HƠN tạo (hạ cấp / rollback) - không mở để khỏi hỏng.
  csdlMoiHon,
}

/// Số lần khởi động liên tiếp chưa ổn định thì lần kế vào chế độ an toàn.
const nguongCrash = 3;

/// Bộ đếm canh gác crash, lưu bền ngoài CSDL (CSDL có thể chính là nguyên
/// nhân crash). Bất biến.
@immutable
final class TrangThaiKhoiDong {
  const new({this.soLanChuaOnDinh = 0, this.anToanChoPhienBan, this.lyDo});

  /// Đọc từ JSON đã lưu; giá trị lạ / thiếu -> mặc định (không ném lỗi).
  factory tuJson(Map<String, Object?> j) {
    final so = j['soLanChuaOnDinh'];
    final pb = j['anToanChoPhienBan'];
    final ly = j['lyDo'];
    return TrangThaiKhoiDong(
      soLanChuaOnDinh: so is int && so > 0 ? so : 0,
      anToanChoPhienBan: pb is String && pb.isNotEmpty ? pb : null,
      lyDo: LyDoAnToan.values.where((v) => v.name == ly).firstOrNull,
    );
  }

  /// Số lần khởi động gần nhất chưa tới ổn định (kể cả lần đang chạy).
  final int soLanChuaOnDinh;

  /// Chế độ an toàn đang ghim cho phiên bản app này (null = không).
  /// Lên bản mới -> thử lại chế độ thường.
  final String? anToanChoPhienBan;

  /// Lý do ghim chế độ an toàn.
  final LyDoAnToan? lyDo;

  Map<String, Object?> toJson() => {
    'soLanChuaOnDinh': soLanChuaOnDinh,
    'anToanChoPhienBan': ?anToanChoPhienBan,
    'lyDo': ?lyDo?.name,
  };

  @override
  bool operator ==(Object other) =>
      other is TrangThaiKhoiDong &&
      other.soLanChuaOnDinh == soLanChuaOnDinh &&
      other.anToanChoPhienBan == anToanChoPhienBan &&
      other.lyDo == lyDo;

  @override
  int get hashCode => Object.hash(soLanChuaOnDinh, anToanChoPhienBan, lyDo);

  @override
  String toString() =>
      'TrangThaiKhoiDong($soLanChuaOnDinh, $anToanChoPhienBan, ${lyDo?.name})';
}

/// Kết quả một lần khởi động: trạng thái mới (GHI NGAY trước khi chạy tiếp)
/// và có vào chế độ an toàn không.
typedef KhoiDong = ({TrangThaiKhoiDong trangThai, LyDoAnToan? anToan});

/// Gọi ĐẦU MỖI lần khởi động, trước mọi thứ có thể crash.
KhoiDong batDauKhoiDong(
  TrangThaiKhoiDong cu, {
  required String phienBan,
  int nguong = nguongCrash,
}) {
  // Bản mới thay bản đang bị ghim -> cho thử lại từ đầu.
  final tt = cu.anToanChoPhienBan != null && cu.anToanChoPhienBan != phienBan
      ? const TrangThaiKhoiDong()
      : cu;
  final dem = tt.soLanChuaOnDinh + 1;
  if (tt.anToanChoPhienBan == phienBan) {
    return (
      trangThai: TrangThaiKhoiDong(
        soLanChuaOnDinh: dem,
        anToanChoPhienBan: phienBan,
        lyDo: tt.lyDo,
      ),
      anToan: tt.lyDo ?? LyDoAnToan.crashLienTiep,
    );
  }
  if (tt.soLanChuaOnDinh >= nguong) {
    return (
      trangThai: TrangThaiKhoiDong(
        soLanChuaOnDinh: dem,
        anToanChoPhienBan: phienBan,
        lyDo: LyDoAnToan.crashLienTiep,
      ),
      anToan: LyDoAnToan.crashLienTiep,
    );
  }
  return (trangThai: TrangThaiKhoiDong(soLanChuaOnDinh: dem), anToan: null);
}

/// App đã chạy ổn định (khung đầu + vài giây, hoặc về nền bình thường):
/// xoá bộ đếm, GIỮ ghim chế độ an toàn nếu có.
TrangThaiKhoiDong daOnDinh(TrangThaiKhoiDong tt) =>
    TrangThaiKhoiDong(anToanChoPhienBan: tt.anToanChoPhienBan, lyDo: tt.lyDo);

/// Người dùng chọn "thử lại chế độ thường".
TrangThaiKhoiDong thoatAnToan(TrangThaiKhoiDong tt) =>
    const TrangThaiKhoiDong();
