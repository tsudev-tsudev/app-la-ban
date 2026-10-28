/// Các bước migration phải chạy để đi từ [tu] lên [den]: [tu+1, ..., den].
/// Ném [StateError] nếu thiếu bước (khai báo sót) hoặc [tu] > [den]
/// (CSDL do bản mới hơn tạo - không được hạ cấp).
List<int> keHoachMigration({
  required int tu,
  required int den,
  required Set<int> coBuoc,
}) {
  if (tu > den) throw StateError('csdl.moiHon: $tu > $den');
  final can = [for (var v = tu + 1; v <= den; v++) v];
  final thieu = can.where((v) => !coBuoc.contains(v)).toList();
  if (thieu.isNotEmpty) throw StateError('csdl.thieuBuoc: $thieu');
  return can;
}
