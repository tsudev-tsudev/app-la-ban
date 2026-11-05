import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cổng đồng ý gửi dữ liệu bảo mật kỹ thuật (QUYET_DINH Q43): đăng ký thiết
/// bị, kênh cấu hình và RASP chỉ gọi máy chủ khi cổng mở. Giá trị theo
/// `CaiDat.trucTuyen` (app.dart đồng bộ), đổi có hiệu lực ngay - trừ thư viện
/// freeRASP đã khởi chạy (không dừng được giữa chừng, hết hẳn từ lần mở sau).
final class CongTrucTuyen extends ValueNotifier<bool> {
  new({required bool mo}) : super(mo);

  /// Chạy [viec] MỘT lần: ngay nếu cổng đang mở, không thì lúc cổng mở lần
  /// đầu (người dùng đồng ý sau ở màn giới thiệu / Quyền riêng tư).
  void khiMo(VoidCallback viec) {
    if (value) {
      viec();
      return;
    }
    void nghe() {
      if (!value) return;
      removeListener(nghe);
      viec();
    }

    addListener(nghe);
  }
}

/// null = không có dịch vụ trực tuyến (test, chế độ an toàn).
final congTrucTuyenProvider = Provider<CongTrucTuyen?>((_) => null);
