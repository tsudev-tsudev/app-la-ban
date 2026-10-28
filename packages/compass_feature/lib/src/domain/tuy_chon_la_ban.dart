import 'package:meta/meta.dart';

/// Tuỳ chọn riêng của tab La bàn (lưu ở tệp JSON không nhạy cảm).
@immutable
final class TuyChonLaBan {
  const new({this.bacThuc = true, this.rung = true});

  /// Đọc JSON đã lưu; khoá thiếu / sai kiểu -> mặc định của trường đó.
  factory tuJson(Map<String, Object?> j) =>
      TuyChonLaBan(bacThuc: j['bacThuc'] != false, rung: j['rung'] != false);

  Map<String, Object?> toJson() => {'bacThuc': bacThuc, 'rung': rung};

  /// Hiện hướng theo bắc thực (cần vị trí) thay vì bắc từ.
  final bool bacThuc;

  /// Rung nhẹ khi kim đi qua 8 hướng chính.
  final bool rung;

  TuyChonLaBan copyWith({bool? bacThuc, bool? rung}) =>
      TuyChonLaBan(bacThuc: bacThuc ?? this.bacThuc, rung: rung ?? this.rung);

  @override
  bool operator ==(Object other) =>
      other is TuyChonLaBan && other.bacThuc == bacThuc && other.rung == rung;

  @override
  int get hashCode => Object.hash(bacThuc, rung);
}
