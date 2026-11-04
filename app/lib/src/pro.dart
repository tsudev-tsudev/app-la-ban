import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:la_ban/src/cong_truc_tuyen.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/kenh.dart';
import 'package:quyen_loi/quyen_loi.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';

/// Kill-switch mở bán trong `tat` của Remote Config ký số (QUYET_DINH Q61).
const tatMuaPro = 'mua-pro';

/// Bản prod chỉ mở bán từ R4 / Release Gate (Q55, Q61): đổi hằng này trong
/// bản phát hành đó. dev / staging mở để thử bằng license tester.
const moBanProTrongProd = false;

/// Gửi giao dịch cho Worker (`POST /v1/mua/xac-minh`, ký S3).
XacMinhMua xacMinhQuaWorker(DichVuDinhDanh dv, String goi) =>
    (sanPham, token) async => ketQuaXacMinh(
      await dv.goiKy(
        'POST',
        '/v1/mua/xac-minh',
        body: {'sanPham': sanPham.ma, 'token': token, 'goi': goi},
      ),
    );

/// Hàm THUẦN: phản hồi `/v1/mua/xac-minh` -> quyền lợi hoặc lỗi hiển thị.
KetQuaXacMinh ketQuaXacMinh(Result<PhanHoiKy> kq) {
  if (kq case Err()) return (quyenLoi: null, loi: LoiMua.mang);
  final r = (kq as Ok<PhanHoiKy>).value;
  if (!r.ok) return (quyenLoi: null, loi: loiTuPhanHoi(r.status, r.ma));
  final q = QuyenLoi.tuJson(r.duLieu?['quyenLoi']);
  return q == null
      ? (quyenLoi: null, loi: LoiMua.mayChu)
      : (quyenLoi: q, loi: null);
}

/// Kho JSON `quyen_loi.json` trong thư mục app.
final class KhoQuyenLoiTep implements KhoQuyenLoi {
  new(this._t);

  final TepJson _t;

  @override
  Map<String, Object?> doc() => _t.duLieu;

  @override
  Future<void> ghi(Map<String, Object?> duLieu) => _t.ghi(duLieu);
}

/// Trang Gói thuê bao của Google Play (huỷ / đổi gói - chính sách Play).
Uri lienKetQuanLyGoi(String goi) => Uri.https(
  'play.google.com',
  '/store/account/subscriptions',
  {'package': goi},
);

/// Dựng dịch vụ quyền lợi (Android + có định danh) và nối với kênh:
/// `/v1/status` mới -> cập nhật quyền lợi; cổng trực tuyến mở -> gửi lại giao
/// dịch dở.
DichVuQuyenLoi? taoDichVuQuyenLoi({
  required Flavor flavor,
  required KhoLuuTru kho,
  required DichVuDinhDanh dinhDanh,
  required KenhApp kenh,
  required CongTrucTuyen cong,
  CuaHang? cuaHang,
}) {
  final dv = DichVuQuyenLoi(
    cuaHang: cuaHang ?? CuaHangPlay(),
    xacMinh: xacMinhQuaWorker(dinhDanh, flavor.goi),
    kho: KhoQuyenLoiTep(TepJson.mo('${kho.thuMuc}/quyen_loi.json')),
    maTaiKhoan: () => maTaiKhoanTuCaiDat(dinhDanh.installationId),
  )..batDau();
  void theoKenh() {
    final q = QuyenLoi.tuJson(kenh.tinhTrang?.quyenLoi);
    if (q != null) unawaited(dv.capNhatTuMayChu(q));
  }

  kenh.addListener(theoKenh);
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => Timer(
      const Duration(seconds: 5),
      () => cong.khiMo(() => unawaited(dv.thuLaiChuaXacNhan())),
    ),
  );
  return dv;
}

/// Ghi đè provider của gói quyen_loi.
List<Override> noiPro(DichVuQuyenLoi? dv, Flavor flavor) => [
  dichVuQuyenLoiProvider.overrideWithValue(dv),
  if (dv != null)
    moQuanLyGoiProvider.overrideWithValue(
      () => moTrangLaBan(lienKetQuanLyGoi(flavor.goi)),
    ),
];

/// Flavor của lần chạy (mục Pro ẩn / hiện theo Q61).
final flavorProvider = Provider<Flavor>((_) => Flavor.dev);

/// Hàm THUẦN: hiện mục Pro trong Cài đặt? Đã có Pro thì luôn hiện (xem
/// trạng thái, Quản lý gói); chưa có thì chỉ khi đang mở bán.
bool hienMucPro({
  required Flavor flavor,
  required Set<String> tat,
  required bool coPro,
  required bool coDichVu,
}) {
  if (!coDichVu) return false;
  if (coPro) return true;
  if (tat.contains(tatMuaPro)) return false;
  return flavor != Flavor.prod || moBanProTrongProd;
}

/// Mục Pro cho `ManCaiDat` (ẩn khi chưa mở bán).
class MucProApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hien = hienMucPro(
      flavor: ref.watch(flavorProvider),
      tat: ref.watch(cauHinhTuXaProvider)?.tat ?? const {},
      coPro: ref.watch(trangThaiQuyenLoiProvider).coPro,
      coDichVu: ref.watch(dichVuQuyenLoiProvider) != null,
    );
    return hien ? const MucPro() : const SizedBox.shrink();
  }
}
