import 'package:meta/meta.dart';
import 'package:settings_feature/src/domain/dong_y.dart';

/// Ngôn ngữ người dùng chọn trong Cài đặt.
enum LuaChonNgonNgu {
  heThong,
  vi,
  en;

  /// Mã ngôn ngữ ép dùng; null = theo hệ thống.
  String? get maNgonNgu => switch (this) {
    LuaChonNgonNgu.heThong => null,
    LuaChonNgonNgu.vi => 'vi',
    LuaChonNgonNgu.en => 'en',
  };
}

/// Chế độ sáng / tối người dùng chọn.
enum CheDoGiaoDien { heThong, sang, toi }

/// Cài đặt giao diện của app (bất biến). Lưu bền qua `KhoCaiDat` (tệp JSON
/// đọc trước khung đầu - không nháy theme, không hiện lại màn giới thiệu).
@immutable
final class CaiDat {
  const new({
    this.ngonNgu = LuaChonNgonNgu.heThong,
    this.cheDo =
        CheDoGiaoDien.toi, // Q68: mặc định Tối (hệ tsudev, phiếu 20261110-05)
    this.daXemGioiThieu = false,
    this.dongY,
    this.baoLoi = false,
  });

  /// Đọc từ JSON đã lưu; khoá thiếu / giá trị lạ (bản cũ, tệp hỏng) -> mặc
  /// định của riêng trường đó.
  factory tuJson(Map<String, Object?> j) => CaiDat(
    ngonNgu:
        LuaChonNgonNgu.values
            .where((v) => v.name == j['ngonNgu'])
            .firstOrNull ??
        LuaChonNgonNgu.heThong,
    cheDo:
        CheDoGiaoDien.values.where((v) => v.name == j['cheDo']).firstOrNull ??
        CheDoGiaoDien.toi,
    daXemGioiThieu: j['daXemGioiThieu'] == true,
    dongY: DongYXuLy.tuJson(j['dongY']),
    baoLoi: j['baoLoi'] == true,
  );

  Map<String, Object?> toJson() => {
    'ngonNgu': ngonNgu.name,
    'cheDo': cheDo.name,
    'daXemGioiThieu': daXemGioiThieu,
    'dongY': ?dongY?.toJson(),
    'baoLoi': baoLoi,
  };

  final LuaChonNgonNgu ngonNgu;
  final CheDoGiaoDien cheDo;

  /// Đã qua màn giới thiệu lần đầu.
  final bool daXemGioiThieu;

  /// Lựa chọn với thông báo xử lý dữ liệu (null = chưa trả lời).
  final DongYXuLy? dongY;

  /// Người dùng bật "Gửi báo cáo sự cố" (S10b, QUYET_DINH Q49) - mặc định TẮT.
  final bool baoLoi;

  /// Được gửi báo cáo sự cố: cần CẢ đồng ý trực tuyến lẫn công tắc riêng
  /// (mục đích khác nhau - Nghị định 13/2023 Điều 11).
  bool get guiBaoLoi => trucTuyen && baoLoi;

  /// Phải qua màn giới thiệu: lần đầu, hoặc thông báo dữ liệu có bản mới.
  bool get canGioiThieu => !daXemGioiThieu || canHoiDongY(dongY);

  /// Được gửi dữ liệu bảo mật kỹ thuật lên máy chủ.
  bool get trucTuyen => choPhepTrucTuyen(dongY);

  CaiDat copyWith({
    LuaChonNgonNgu? ngonNgu,
    CheDoGiaoDien? cheDo,
    bool? daXemGioiThieu,
    DongYXuLy? dongY,
    bool? baoLoi,
  }) => CaiDat(
    ngonNgu: ngonNgu ?? this.ngonNgu,
    cheDo: cheDo ?? this.cheDo,
    daXemGioiThieu: daXemGioiThieu ?? this.daXemGioiThieu,
    dongY: dongY ?? this.dongY,
    baoLoi: baoLoi ?? this.baoLoi,
  );

  @override
  bool operator ==(Object other) =>
      other is CaiDat &&
      other.ngonNgu == ngonNgu &&
      other.cheDo == cheDo &&
      other.daXemGioiThieu == daXemGioiThieu &&
      other.dongY == dongY &&
      other.baoLoi == baoLoi;

  @override
  int get hashCode =>
      Object.hash(ngonNgu, cheDo, daXemGioiThieu, dongY, baoLoi);

  @override
  String toString() =>
      'CaiDat(ngonNgu: ${ngonNgu.name}, cheDo: ${cheDo.name}, '
      'daXemGioiThieu: $daXemGioiThieu, dongY: $dongY, baoLoi: $baoLoi)';
}
