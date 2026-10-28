import 'package:location_feature/src/domain/toa_do.dart';
import 'package:meta/meta.dart';

/// Tuỳ chọn lưu bền của phần vị trí (`vi_tri.json`).
@immutable
final class TuyChonViTri {
  const new({this.dinhDang = DinhDangToaDo.dd, this.viDoLuu, this.kinhDoLuu});

  factory tuJson(Map<String, Object?> j) {
    double? so(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
    final vi = so(j['viDo']);
    final kinh = so(j['kinhDo']);
    final hopLe =
        vi != null && kinh != null && vi.abs() <= 90 && kinh.abs() <= 180;
    return TuyChonViTri(
      dinhDang: DinhDangToaDo.values.firstWhere(
        (d) => d.name == j['dinhDang'],
        orElse: () => DinhDangToaDo.dd,
      ),
      viDoLuu: hopLe ? vi : null,
      kinhDoLuu: hopLe ? kinh : null,
    );
  }

  final DinhDangToaDo dinhDang;

  /// Vị trí gần nhất đã làm tròn 0,1° (`lamTronLuu`).
  final double? viDoLuu;
  final double? kinhDoLuu;

  Map<String, Object?> toJson() => {
    'dinhDang': dinhDang.name,
    if (viDoLuu != null) 'viDo': viDoLuu,
    if (kinhDoLuu != null) 'kinhDo': kinhDoLuu,
  };

  TuyChonViTri copyWith({
    DinhDangToaDo? dinhDang,
    double? viDoLuu,
    double? kinhDoLuu,
  }) => TuyChonViTri(
    dinhDang: dinhDang ?? this.dinhDang,
    viDoLuu: viDoLuu ?? this.viDoLuu,
    kinhDoLuu: kinhDoLuu ?? this.kinhDoLuu,
  );

  @override
  bool operator ==(Object other) =>
      other is TuyChonViTri &&
      other.dinhDang == dinhDang &&
      other.viDoLuu == viDoLuu &&
      other.kinhDoLuu == kinhDoLuu;

  @override
  int get hashCode => Object.hash(dinhDang, viDoLuu, kinhDoLuu);
}
