import 'package:core/src/nhat_ky.dart';

/// Báo cáo sự cố app (S10b, QUYET_DINH Q49) - tự xây thay Sentry / Crashlytics:
/// không SDK bên thứ ba, gửi về Worker của dự án qua yêu cầu ký thiết bị, chỉ
/// khi người dùng bật "Gửi báo cáo sự cố". Ngăn xếp bản release đã che mã
/// (`--obfuscate`) - giải mã ở máy dev bằng symbol giữ ngoài repo.
final class BaoCaoLoi {
  const new({
    required this.loai,
    required this.kieu,
    required this.thongDiep,
    required this.nganXep,
    required this.phienBan,
    required this.luc,
  });

  /// `flutter` (FlutterError) | `dart` (lỗi không bắt ở zone / isolate).
  final String loai;

  /// Kiểu lỗi (`runtimeType` - bản release là tên đã che).
  final String kieu;

  /// Thông điệp đã qua [cheNhatKy] (token, toạ độ, chuỗi dài bị che).
  final String thongDiep;
  final String nganXep;
  final String phienBan;

  /// Mili giây epoch lúc xảy ra.
  final int luc;

  Map<String, Object?> toJson() => {
    'loai': loai,
    'kieu': kieu,
    'thongDiep': thongDiep,
    'nganXep': nganXep,
    'phienBan': phienBan,
    'luc': luc,
  };

  /// Đọc lại từ hàng đợi trên máy; sai dạng -> null (bỏ qua bản ghi hỏng).
  static BaoCaoLoi? tuJson(Object? j) {
    if (j is! Map) return null;
    final loai = j['loai'];
    final kieu = j['kieu'];
    final thongDiep = j['thongDiep'];
    final nganXep = j['nganXep'];
    final phienBan = j['phienBan'];
    final luc = j['luc'];
    if (loai is! String ||
        kieu is! String ||
        thongDiep is! String ||
        nganXep is! String ||
        phienBan is! String ||
        luc is! int) {
      return null;
    }
    return BaoCaoLoi(
      loai: loai,
      kieu: kieu,
      thongDiep: thongDiep,
      nganXep: nganXep,
      phienBan: phienBan,
      luc: luc,
    );
  }
}

/// Giới hạn khớp schema Worker (`/v1/app/su-co`).
const doDaiThongDiepToiDa = 500;
const doDaiNganXepToiDa = 8000;
const hangDoiToiDa = 20;
const loGuiToiDa = 10;

String _cat(String s, int n) => s.length <= n ? s : s.substring(0, n);

/// Dựng báo cáo từ lỗi bắt được: che thông điệp, cắt độ dài (giữ phần ĐẦU
/// ngăn xếp - khung gần lỗi nhất).
BaoCaoLoi taoBaoCaoLoi({
  required String loai,
  required Object loi,
  required String phienBan,
  required int luc,
  StackTrace? nganXep,
}) => BaoCaoLoi(
  loai: loai,
  kieu: _cat(loi.runtimeType.toString(), 120),
  thongDiep: _cat(cheNhatKy(loi.toString()), doDaiThongDiepToiDa),
  nganXep: _cat(nganXep?.toString() ?? '', doDaiNganXepToiDa),
  phienBan: phienBan,
  luc: luc,
);

/// Thêm vào hàng đợi: bỏ bản trùng (cùng kiểu + ngăn xếp - lỗi lặp trong vòng
/// dựng khung) và giữ tối đa [toiDa] bản MỚI nhất.
List<BaoCaoLoi> themVaoHang(
  List<BaoCaoLoi> hang,
  BaoCaoLoi moi, {
  int toiDa = hangDoiToiDa,
}) {
  if (hang.any((b) => b.kieu == moi.kieu && b.nganXep == moi.nganXep)) {
    return hang;
  }
  final ra = [...hang, moi];
  return ra.length <= toiDa ? ra : ra.sublist(ra.length - toiDa);
}
