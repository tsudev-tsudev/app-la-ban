import 'package:meta/meta.dart';

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

/// Cài đặt giao diện của app (bất biến). Lưu bền ở A5 (storage mã hoá).
@immutable
final class CaiDat {
  const new({
    this.ngonNgu = LuaChonNgonNgu.heThong,
    this.cheDo = CheDoGiaoDien.heThong,
    this.daXemGioiThieu = false,
  });

  final LuaChonNgonNgu ngonNgu;
  final CheDoGiaoDien cheDo;

  /// Đã qua màn giới thiệu lần đầu.
  final bool daXemGioiThieu;

  CaiDat copyWith({
    LuaChonNgonNgu? ngonNgu,
    CheDoGiaoDien? cheDo,
    bool? daXemGioiThieu,
  }) => CaiDat(
    ngonNgu: ngonNgu ?? this.ngonNgu,
    cheDo: cheDo ?? this.cheDo,
    daXemGioiThieu: daXemGioiThieu ?? this.daXemGioiThieu,
  );

  @override
  bool operator ==(Object other) =>
      other is CaiDat &&
      other.ngonNgu == ngonNgu &&
      other.cheDo == cheDo &&
      other.daXemGioiThieu == daXemGioiThieu;

  @override
  int get hashCode => Object.hash(ngonNgu, cheDo, daXemGioiThieu);

  @override
  String toString() =>
      'CaiDat(ngonNgu: ${ngonNgu.name}, cheDo: ${cheDo.name}, '
      'daXemGioiThieu: $daXemGioiThieu)';
}
