import 'dart:async';

import 'package:app_shell/src/cong_truc_tuyen.dart';
import 'package:app_shell/src/flavor.dart';
import 'package:app_shell/src/kenh.dart';
import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
/// App Pro (M2): không bán gói -> cửa hàng rỗng, quyền lợi `pro_app` chỉ đến
/// từ `/v1/status`.
DichVuQuyenLoi? taoDichVuQuyenLoi({
  required CauHinhSanPham cauHinh,
  required KhoLuuTru kho,
  required DichVuDinhDanh dinhDanh,
  required KenhApp kenh,
  required CongTrucTuyen cong,
  CuaHang? cuaHang,
}) {
  final dv = DichVuQuyenLoi(
    cuaHang:
        cuaHang ?? (cauHinh.laPro ? const CuaHangKhongBan() : CuaHangPlay()),
    xacMinh: xacMinhQuaWorker(dinhDanh, cauHinh.goi),
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

/// App Pro: hộp thoại GET_LICENSED của Play rồi [xacMinhLai] thiết bị
/// (Worker đọc `appLicensingVerdict` -> cấp `pro_app`) và [lamMoi]
/// `/v1/status`. Trả theo hợp đồng của `khacPhucBanQuyenProvider`.
Future<bool?> Function() khacPhucBanQuyen({
  required Future<void> Function() xacMinhLai,
  Future<KetQuaHopThoaiBanQuyen> Function(int) moHopThoai = moHopThoaiBanQuyen,
  Future<void> Function()? lamMoi,
}) => () async {
  switch (await moHopThoai(Flavor.soDuAnCloud)) {
    case KetQuaHopThoaiBanQuyen.huy:
      return null;
    case KetQuaHopThoaiBanQuyen.khongKhaDung:
      return false;
    case KetQuaHopThoaiBanQuyen.thanhCong:
      await xacMinhLai();
      await lamMoi?.call();
      return true;
  }
};

/// Ghi đè provider của gói quyen_loi.
List<Override> noiPro(
  DichVuQuyenLoi? dv,
  CauHinhSanPham cauHinh,
  DichVuDinhDanh? dinhDanh, {
  Future<void> Function()? lamMoi,
}) => [
  dichVuQuyenLoiProvider.overrideWithValue(dv),
  if (dv != null && !cauHinh.laPro)
    moQuanLyGoiProvider.overrideWithValue(
      () => moTrangLaBan(lienKetQuanLyGoi(cauHinh.goi)),
    ),
  if (cauHinh.laPro && dinhDanh != null)
    khacPhucBanQuyenProvider.overrideWithValue(
      khacPhucBanQuyen(xacMinhLai: dinhDanh.xacMinhLai, lamMoi: lamMoi),
    ),
];

/// Cấu hình bản build đang chạy (mục Pro ẩn / hiện theo Q61; app Pro hiện mục
/// bản quyền).
final cauHinhSanPhamProvider = Provider<CauHinhSanPham>(
  (_) => const CauHinhSanPham(
    flavor: Flavor.dev,
    loai: LoaiApp.mienPhi,
    phienBan: '0.0.0+1',
  ),
);

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

/// Mục Pro cho `ManCaiDat`: app Pro -> mục bản quyền; app miễn phí -> mục
/// mua Pro (ẩn khi chưa mở bán).
class MucProApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cauHinh = ref.watch(cauHinhSanPhamProvider);
    if (cauHinh.laPro) return const MucBanQuyenPro();
    final hien = hienMucPro(
      flavor: cauHinh.flavor,
      tat: ref.watch(cauHinhTuXaProvider)?.tat ?? const {},
      coPro: ref.watch(trangThaiQuyenLoiProvider).coPro,
      coDichVu: ref.watch(dichVuQuyenLoiProvider) != null,
    );
    return hien ? const MucPro() : const SizedBox.shrink();
  }
}
