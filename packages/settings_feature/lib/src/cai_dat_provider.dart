import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settings_feature/src/domain/cai_dat.dart';

/// Trạng thái cài đặt giao diện. App chỉ `select` đúng trường cần để đổi
/// ngôn ngữ / theme không dựng lại cả cây.
final caiDatProvider = NotifierProvider<CaiDatNotifier, CaiDat>(
  CaiDatNotifier.new,
);

class CaiDatNotifier extends Notifier<CaiDat> {
  @override
  CaiDat build() => const CaiDat();

  void datNgonNgu(LuaChonNgonNgu v) => state = state.copyWith(ngonNgu: v);

  void datCheDo(CheDoGiaoDien v) => state = state.copyWith(cheDo: v);

  void xongGioiThieu() => state = state.copyWith(daXemGioiThieu: true);
}
