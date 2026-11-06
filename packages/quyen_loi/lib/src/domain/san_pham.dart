import 'package:meta/meta.dart';

/// Sản phẩm Play đã chốt (QUYET_DINH Q55) - khớp `SAN_PHAM` của Worker
/// (`workers/api/src/thuan/quyen-loi.ts`). Thứ tự = thứ tự hiện trên Paywall.
enum SanPham {
  proNam('pro_nam', dangKy: true),
  proThang('pro_thang', dangKy: true),
  // Mã `pro_vinh_vien` đã bị xoá trên Play Console và Play không cho dùng lại
  // mã đã xoá -> mã mới `pro_tron_doi` (QUYET_DINH Q67, 06/11/2026).
  proVinhVien('pro_tron_doi', dangKy: false);

  new(this.ma, {required this.dangKy});

  /// Product ID trên Play Console.
  final String ma;

  /// true: gói đăng ký tự gia hạn; false: mua một lần (non-consumable).
  final bool dangKy;

  static SanPham? tuMa(String ma) {
    for (final s in values) {
      if (s.ma == ma) return s;
    }
    return null;
  }

  static Set<String> get dsMa => {for (final s in values) s.ma};
}

/// Một giai đoạn giá của ưu đãi gói đăng ký (Play `PricingPhase`).
@immutable
final class GiaiDoanGia {
  const new({
    required this.giaMicros,
    required this.giaHienThi,
    required this.kyHan,
    required this.soChuKy,
    required this.lapVoHan,
  });

  final int giaMicros;

  /// Giá Play đã định dạng theo vùng (không ghi cứng giá - M1a bước 2).
  final String giaHienThi;

  /// Kỳ ISO 8601 (`P1M`, `P1Y`, `P7D`...).
  final String kyHan;
  final int soChuKy;
  final bool lapVoHan;

  bool get mienPhi => giaMicros == 0;
}

/// Một ưu đãi (base plan hoặc offer) của gói đăng ký.
@immutable
final class UuDai {
  const new({
    required this.basePlan,
    required this.offerId,
    required this.giaiDoan,
    required this.chiSo,
  });

  final String basePlan;

  /// null = base plan gốc (không khuyến mãi).
  final String? offerId;
  final List<GiaiDoanGia> giaiDoan;

  /// Vị trí trong danh sách của Play (để lấy lại đúng offer token).
  final int chiSo;

  /// Giai đoạn gia hạn (giá sau khuyến mãi / dùng thử).
  GiaiDoanGia? get giaGiaHan => giaiDoan.isEmpty
      ? null
      : giaiDoan.lastWhere((g) => g.lapVoHan, orElse: () => giaiDoan.last);

  /// Số ngày dùng thử miễn phí (giai đoạn đầu giá 0), null nếu không có.
  int? get ngayDungThu {
    if (giaiDoan.isEmpty || !giaiDoan.first.mienPhi) return null;
    final g = giaiDoan.first;
    final ngay = soNgayKyHan(g.kyHan);
    return ngay == null ? null : ngay * (g.soChuKy < 1 ? 1 : g.soChuKy);
  }
}

/// Hàm THUẦN: chọn ưu đãi hiện trên Paywall cho một gói đăng ký: ưu tiên ưu
/// đãi có dùng thử miễn phí (Play chỉ trả offer người dùng còn đủ điều kiện),
/// sau đó base plan gốc; trong cùng loại chọn chỉ số nhỏ nhất (ổn định).
UuDai? chonUuDai(List<UuDai> ds) {
  if (ds.isEmpty) return null;
  int hang(UuDai u) => u.ngayDungThu != null
      ? 0
      : u.offerId == null
      ? 1
      : 2;
  final xep = [...ds]
    ..sort((a, b) {
      final h = hang(a).compareTo(hang(b));
      return h != 0 ? h : a.chiSo.compareTo(b.chiSo);
    });
  return xep.first;
}

/// Kỳ ISO 8601 của Play -> số ngày xấp xỉ (tháng 30, năm 365); sai dạng ->
/// null.
int? soNgayKyHan(String kyHan) {
  final m = RegExp(r'^P(\d+)([DWMY])$').firstMatch(kyHan);
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  return switch (m.group(2)) {
    'D' => n,
    'W' => n * 7,
    'M' => n * 30,
    _ => n * 365,
  };
}

/// Đơn vị kỳ gia hạn để chọn chuỗi "/ tháng", "/ năm".
enum DonViKy { ngay, tuan, thang, nam }

/// `P1M` -> tháng; `P1Y` / `P12M` -> năm; sai dạng -> null.
DonViKy? donViKy(String kyHan) {
  final m = RegExp(r'^P(\d+)([DWMY])$').firstMatch(kyHan);
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  return switch (m.group(2)) {
    'D' => DonViKy.ngay,
    'W' => DonViKy.tuan,
    'M' => n == 12 ? DonViKy.nam : DonViKy.thang,
    _ => DonViKy.nam,
  };
}

/// Gói hiển thị trên Paywall (đã chọn ưu đãi). [nguon] = đối tượng của plugin
/// cửa hàng (lớp dữ liệu dùng lại khi mua; domain không đọc).
@immutable
final class GoiBan {
  const new({
    required this.sanPham,
    required this.giaHienThi,
    this.donVi,
    this.ngayDungThu,
    this.nguon,
  });

  final SanPham sanPham;

  /// Giá gia hạn (gói đăng ký) hoặc giá một lần.
  final String giaHienThi;
  final DonViKy? donVi;
  final int? ngayDungThu;
  final Object? nguon;
}

/// Sắp các gói theo thứ tự [SanPham.values], bỏ trùng sản phẩm.
List<GoiBan> sapXepGoi(Iterable<GoiBan> ds) {
  final theoSp = <SanPham, GoiBan>{};
  for (final g in ds) {
    theoSp.putIfAbsent(g.sanPham, () => g);
  }
  return [for (final s in SanPham.values) ?theoSp[s]];
}
