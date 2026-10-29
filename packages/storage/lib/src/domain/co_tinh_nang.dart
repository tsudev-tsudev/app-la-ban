/// Cờ tính năng cục bộ (Spec §10.4). Chức năng la bàn cơ bản và xuất dữ liệu
/// điểm KHÔNG có cờ - luôn chạy, kể cả ở chế độ an toàn.
enum CoTinhNang {
  banDo,
  ar,
  chiaSe,
  dongBo,
  quangCao;

  /// Mặc định khi chưa có ghi đè. Quảng cáo chỉ bật sau Release Gate (Q17).
  bool get macDinh => this != CoTinhNang.quangCao;
}

/// Giá trị cuối của mọi cờ. Thứ tự ưu tiên (cao -> thấp): chế độ an toàn tắt
/// hết -> kill-switch từ xa (chỉ TẮT được) -> ghi đè cục bộ -> mặc định.
Map<CoTinhNang, bool> tinhCo({
  Map<CoTinhNang, bool> cucBo = const {},
  Set<CoTinhNang> tatTuXa = const {},
  bool anToan = false,
}) => {
  for (final c in CoTinhNang.values)
    c: !anToan && !tatTuXa.contains(c) && (cucBo[c] ?? c.macDinh),
};

/// Đọc ghi đè cục bộ từ JSON; khoá / giá trị lạ bị bỏ qua.
Map<CoTinhNang, bool> coTuJson(Map<String, Object?> j) => {
  for (final c in CoTinhNang.values)
    if (j[c.name] case final bool v) c: v,
};

/// Ghi đè cục bộ -> JSON.
Map<String, Object?> coRaJson(Map<CoTinhNang, bool> co) => {
  for (final MapEntry(:key, :value) in co.entries) key.name: value,
};

/// Tên cờ trong Remote Config (`ban-do`, `chia-se`...) -> cờ; tên lạ bị bỏ
/// qua (Remote Config của bản mới có thể có cờ bản cũ chưa biết).
Set<CoTinhNang> coTuTenTuXa(Iterable<String> ten) => {
  for (final c in CoTinhNang.values)
    if (ten.contains(
      c.name.replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '-${m[0]!.toLowerCase()}',
      ),
    ))
      c,
};
