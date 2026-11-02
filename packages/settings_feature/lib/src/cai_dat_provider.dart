import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_feature/src/domain/cai_dat.dart';
import 'package:settings_feature/src/domain/dong_y.dart';
import 'package:settings_feature/src/kho_cai_dat.dart';

/// Kho lưu bền cài đặt. App override bằng `KhoCaiDatTep` lúc khởi động.
final khoCaiDatProvider = Provider<KhoCaiDat>((_) => KhoCaiDatBoNho());

/// Trạng thái cài đặt giao diện. App chỉ `select` đúng trường cần để đổi
/// ngôn ngữ / theme không dựng lại cả cây.
final caiDatProvider = NotifierProvider<CaiDatNotifier, CaiDat>(
  CaiDatNotifier.new,
);

class CaiDatNotifier extends Notifier<CaiDat> {
  @override
  CaiDat build() => ref.read(khoCaiDatProvider).doc();

  void datNgonNgu(LuaChonNgonNgu v) => _dat(state.copyWith(ngonNgu: v));

  void datCheDo(CheDoGiaoDien v) => _dat(state.copyWith(cheDo: v));

  void xongGioiThieu() => _dat(state.copyWith(daXemGioiThieu: true));

  /// Trả lời thông báo xử lý dữ liệu (màn giới thiệu) hoặc đổi / rút đồng ý
  /// (màn Quyền riêng tư). Luôn ghi bản thông báo hiện hành + thời điểm.
  void datDongY({required bool trucTuyen, DateTime? luc}) => _dat(
    state.copyWith(
      daXemGioiThieu: true,
      dongY: DongYXuLy(
        ban: banThongBaoDuLieu,
        trucTuyen: trucTuyen,
        luc: luc ?? DateTime.now(),
      ),
    ),
  );

  /// Bật / tắt gửi báo cáo sự cố (S10b). Chỉ có hiệu lực khi đã đồng ý
  /// trực tuyến (`CaiDat.guiBaoLoi`).
  void datBaoLoi({required bool bat}) => _dat(state.copyWith(baoLoi: bat));

  // Ghi nền theo thứ tự gọi; giao diện đổi ngay, không chờ đĩa.
  void _dat(CaiDat moi) {
    state = moi;
    ref.read(khoCaiDatProvider).ghi(moi).ignore();
  }
}
