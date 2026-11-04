import 'package:meta/meta.dart';

/// Phần `quyenLoi` của `/v1/status` (Worker quyết - IAP-01): app KHÔNG tự mở
/// khoá theo kết quả Billing Library, chỉ hiển thị theo bản này.
@immutable
final class QuyenLoi {
  const new({required this.pro, required this.khongQuangCao, this.hetHan});

  static const mienPhi = QuyenLoi(pro: false, khongQuangCao: false);

  final bool pro;
  final bool khongQuangCao;

  /// Hết hạn (ms epoch); null + [pro] = vĩnh viễn (mua một lần / app Pro).
  final int? hetHan;

  bool get vinhVien => pro && hetHan == null;

  /// JSON của Worker (`schemaQuyenLoi`) -> quyền lợi; sai dạng -> null.
  static QuyenLoi? tuJson(Object? j) {
    if (j is! Map<String, Object?>) return null;
    final pro = j['pro'];
    final kqc = j['khongQuangCao'];
    final het = j['hetHan'];
    if (pro is! bool || kqc is! bool) return null;
    if (het != null && het is! int) return null;
    return QuyenLoi(pro: pro, khongQuangCao: kqc, hetHan: het as int?);
  }

  Map<String, Object?> toJson() => {
    'pro': pro,
    'khongQuangCao': khongQuangCao,
    'hetHan': hetHan,
  };

  @override
  bool operator ==(Object other) =>
      other is QuyenLoi &&
      other.pro == pro &&
      other.khongQuangCao == khongQuangCao &&
      other.hetHan == hetHan;

  @override
  int get hashCode => Object.hash(pro, khongQuangCao, hetHan);
}

/// Mức quyền lợi app đang áp dụng.
enum MucQuyenLoi {
  /// Không có quyền lợi (hoặc đã hết hạn).
  mienPhi,

  /// Còn hạn theo phản hồi gần nhất của máy chủ.
  pro,

  /// Gói đăng ký đã qua [QuyenLoi.hetHan] nhưng app chưa hỏi lại được máy
  /// chủ từ lúc đó (thường đã tự gia hạn) -> giữ Pro thêm một thời gian ân hạn.
  anHan,
}

/// Quyền lợi đang hiệu lực + mức.
@immutable
final class TrangThaiQuyenLoi {
  const new(this.muc, this.quyenLoi);

  final MucQuyenLoi muc;
  final QuyenLoi quyenLoi;

  bool get coPro => muc != MucQuyenLoi.mienPhi;

  /// Không khởi tạo AdMob / UMP (M1 nguyên tắc 2) khi có quyền lợi này.
  bool get khongQuangCao => coPro && quyenLoi.khongQuangCao;
}

/// Ân hạn offline mặc định sau [QuyenLoi.hetHan] (Play cũng cho gói đăng ký
/// ân hạn thanh toán vài ngày; máy chủ trả hạn mới khi đã gia hạn).
const anHanMacDinh = Duration(days: 3);

/// Hàm THUẦN: quyền lợi đang áp dụng từ bản lưu gần nhất của máy chủ.
///
/// [nhanLuc] = lúc nhận bản đó (ms, giờ máy). Đồng hồ máy bị chỉnh lùi về
/// trước [nhanLuc] -> coi như đang ở [nhanLuc] (không kéo dài được hạn bằng
/// cách lùi giờ). Gói vĩnh viễn giữ tới khi máy chủ báo khác.
TrangThaiQuyenLoi tinhQuyenLoi({
  required QuyenLoi? daLuu,
  required int? nhanLuc,
  required int bayGio,
  Duration anHan = anHanMacDinh,
}) {
  final q = daLuu;
  if (q == null || !q.pro) {
    return const TrangThaiQuyenLoi(MucQuyenLoi.mienPhi, QuyenLoi.mienPhi);
  }
  final het = q.hetHan;
  if (het == null) return TrangThaiQuyenLoi(MucQuyenLoi.pro, q);
  final nhan = nhanLuc ?? 0;
  final t = bayGio < nhan ? nhan : bayGio;
  if (t < het) return TrangThaiQuyenLoi(MucQuyenLoi.pro, q);
  // Chưa hỏi lại được máy chủ từ lúc hết hạn (gói thường đã tự gia hạn, hạn
  // mới về ở `/v1/status` kế tiếp) -> giữ Pro trong [anHan].
  if (t < het + anHan.inMilliseconds) {
    return TrangThaiQuyenLoi(MucQuyenLoi.anHan, q);
  }
  return const TrangThaiQuyenLoi(MucQuyenLoi.mienPhi, QuyenLoi.mienPhi);
}
