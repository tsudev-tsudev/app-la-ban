/// Phản hồi JSON tối thiểu mà định danh cần (app nối từ `network`).
typedef PhanHoiDinhDanh = ({int status, Map<String, Object?>? duLieu});

/// Cổng gọi API. Gói này KHÔNG phụ thuộc `network`: ở S3 `network` dùng
/// khoá thiết bị của gói này để ký request (phụ thuộc đi một chiều).
abstract interface class ApiDinhDanh {
  /// Ném [LoiKetNoi] khi không tới được server.
  Future<PhanHoiDinhDanh> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  });
}

/// Không kết nối được / hết giờ.
final class LoiKetNoi implements Exception {
  const new(this.lyDo);

  final String lyDo;

  @override
  String toString() => 'LoiKetNoi($lyDo)';
}

/// Tệp trạng thái nhỏ ghi nguyên tử (app nối bằng `storage.TepJson`).
abstract interface class KhoTrangThai {
  Map<String, Object?> get duLieu;

  void ghiDongBo(Map<String, Object?> moi);

  Future<void> ghi(Map<String, Object?> moi);
}

extension MaLoi on PhanHoiDinhDanh {
  bool get ok => status >= 200 && status < 300;

  String? get ma => duLieu?['code'] as String?;
}
