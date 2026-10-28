import 'package:compass_feature/src/domain/tuy_chon_la_ban.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage/storage.dart';

/// Nơi lưu bền [TuyChonLaBan]. Đọc ĐỒNG BỘ (đã nạp trước khung đầu).
abstract interface class KhoTuyChonLaBan {
  TuyChonLaBan doc();

  Future<void> ghi(TuyChonLaBan t);
}

/// Chỉ giữ trong bộ nhớ (mặc định khi chưa có kho thật, test).
final class KhoTuyChonLaBanBoNho implements KhoTuyChonLaBan {
  new([this._t = const TuyChonLaBan()]);

  TuyChonLaBan _t;

  @override
  TuyChonLaBan doc() => _t;

  @override
  Future<void> ghi(TuyChonLaBan t) async => _t = t;
}

/// Lưu ở tệp JSON nguyên tử `la_ban.json` của `KhoLuuTru`.
final class KhoTuyChonLaBanTep implements KhoTuyChonLaBan {
  const new(this._tep);

  final TepJson _tep;

  @override
  TuyChonLaBan doc() => TuyChonLaBan.tuJson(_tep.duLieu);

  @override
  Future<void> ghi(TuyChonLaBan t) => _tep.ghi(t.toJson());
}

/// Kho tuỳ chọn. App override bằng `KhoTuyChonLaBanTep` lúc khởi động.
final khoTuyChonLaBanProvider = Provider<KhoTuyChonLaBan>(
  (_) => KhoTuyChonLaBanBoNho(),
);

final tuyChonLaBanProvider =
    NotifierProvider<TuyChonLaBanNotifier, TuyChonLaBan>(
      TuyChonLaBanNotifier.new,
    );

class TuyChonLaBanNotifier extends Notifier<TuyChonLaBan> {
  @override
  TuyChonLaBan build() => ref.read(khoTuyChonLaBanProvider).doc();

  void datBacThuc({required bool bat}) => _dat(state.copyWith(bacThuc: bat));

  void datRung({required bool bat}) => _dat(state.copyWith(rung: bat));

  // Giao diện đổi ngay, ghi đĩa ở nền.
  void _dat(TuyChonLaBan moi) {
    state = moi;
    ref.read(khoTuyChonLaBanProvider).ghi(moi).ignore();
  }
}
