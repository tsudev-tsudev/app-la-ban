import 'package:settings_feature/src/domain/cai_dat.dart';
import 'package:storage/storage.dart';

/// Nơi lưu bền [CaiDat]. Đọc ĐỒNG BỘ (đã nạp trước khung đầu).
abstract interface class KhoCaiDat {
  CaiDat doc();

  Future<void> ghi(CaiDat c);
}

/// Chỉ giữ trong bộ nhớ (mặc định khi chưa có kho thật, test).
final class KhoCaiDatBoNho implements KhoCaiDat {
  new([this._c = const CaiDat()]);

  CaiDat _c;

  @override
  CaiDat doc() => _c;

  @override
  Future<void> ghi(CaiDat c) async => _c = c;
}

/// Lưu ở tệp JSON nguyên tử của `KhoLuuTru` (không nhạy cảm, phải sống cả
/// khi CSDL mã hoá lỗi).
final class KhoCaiDatTep implements KhoCaiDat {
  const new(this._tep);

  final TepJson _tep;

  @override
  CaiDat doc() => CaiDat.tuJson(_tep.duLieu);

  @override
  Future<void> ghi(CaiDat c) => _tep.ghi(c.toJson());
}
