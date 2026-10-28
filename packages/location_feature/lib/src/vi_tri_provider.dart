import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location_feature/src/domain/cao_do.dart';
import 'package:location_feature/src/domain/dia_gioi.dart';
import 'package:location_feature/src/domain/doc_vi_tri.dart';
import 'package:location_feature/src/domain/geoid.dart';
import 'package:location_feature/src/domain/toa_do.dart';
import 'package:location_feature/src/domain/tuy_chon_vi_tri.dart';
import 'package:location_feature/src/du_lieu/nguon_vi_tri.dart';
import 'package:sensors/sensors.dart';
import 'package:storage/storage.dart';

/// Nguồn vị trí. Test / golden override bằng `NguonViTriGhiSan`.
final nguonViTriProvider = Provider<NguonViTri>(
  (_) => const NguonViTriNenTang(),
);

/// Quyền vị trí hiện tại. Đọc lại khi app trở lại tiền cảnh (người dùng có
/// thể vừa đổi trong Cài đặt hệ thống) qua [QuyenViTriNotifier.lamMoi].
final quyenViTriProvider =
    AsyncNotifierProvider<QuyenViTriNotifier, QuyenViTri>(
      QuyenViTriNotifier.new,
    );

class QuyenViTriNotifier extends AsyncNotifier<QuyenViTri> {
  @override
  Future<QuyenViTri> build() => ref.read(nguonViTriProvider).quyen();

  Future<void> lamMoi() async {
    final q = await ref.read(nguonViTriProvider).quyen();
    if (state.value != q) state = AsyncData(q);
  }

  /// Chỉ gọi từ thao tác của người dùng (just-in-time).
  Future<void> xin() async {
    state = AsyncData(await ref.read(nguonViTriProvider).xinQuyen());
  }
}

/// Luồng vị trí. autoDispose: chỉ chạy khi có màn đang thấy cần vị trí.
/// Chưa có quyền -> không bao giờ phát (giao diện hiện lời mời bật).
final StreamProvider<DocViTri> docViTriProvider = StreamProvider.autoDispose((
  ref,
) {
  final q = ref.watch(quyenViTriProvider).value;
  if (q == null || !q.duocPhep) return const Stream.empty();
  return ref.watch(nguonViTriProvider).theoDoi();
}, retry: (_, _) => null);

/// Tài nguyên tra cứu ngoại tuyến (asset), nạp một lần khi cần.
typedef TaiNguyenViTri = ({BanDoDiaGioi diaGioi, LuoiGeoid geoid});

final taiNguyenViTriProvider = FutureProvider<TaiNguyenViTri>((ref) async {
  const goc = 'packages/location_feature/assets';
  final dg = await rootBundle.load('$goc/dia_gioi_vn.bin');
  final ge = await rootBundle.load('$goc/geoid_egm96_1do.bin');
  return (
    diaGioi: BanDoDiaGioi.tuBytes(
      dg.buffer.asUint8List(dg.offsetInBytes, dg.lengthInBytes),
    ),
    geoid: LuoiGeoid.tuBytes(ge),
  );
});

/// Địa giới tại vị trí hiện tại; chỉ tra lại khi dời > ~10 m (làm tròn
/// 1e-4°).
final Provider<DiaGioi?> diaGioiProvider = Provider.autoDispose((ref) {
  final o = ref.watch(
    docViTriProvider.select(
      (v) =>
          v.whenData((d) => ((d.viDo * 1e4).round(), (d.kinhDo * 1e4).round())),
    ),
  );
  final tn = ref.watch(taiNguyenViTriProvider).value;
  final (vi, kinh) = o.value ?? (null, null);
  if (tn == null || vi == null || kinh == null) return null;
  return tn.diaGioi.tra(vi / 1e4, kinh / 1e4);
});

/// Hiệu chỉnh khí áp kế (sống cả phiên app).
final boHieuChinhKhiApProvider = Provider<BoHieuChinhKhiAp>(
  (_) => BoHieuChinhKhiAp(),
);

/// Độ cao trên mực biển (m) của lần đọc: nền tảng có sẵn (Android 14+) thì
/// dùng, không thì elipxoit - geoid EGM96.
double? doCaoMucBien(DocViTri d, LuoiGeoid? geoid) {
  if (d.doCaoMucBien != null) return d.doCaoMucBien;
  final h = d.doCaoElip;
  if (h == null || geoid == null) return null;
  return geoid.doCaoMucBien(d.viDo, d.kinhDo, h);
}

/// Nơi lưu bền [TuyChonViTri]. Đọc ĐỒNG BỘ (đã nạp trước khung đầu).
abstract interface class KhoViTri {
  TuyChonViTri doc();

  Future<void> ghi(TuyChonViTri t);
}

final class KhoViTriBoNho implements KhoViTri {
  new([this._t = const TuyChonViTri()]);

  TuyChonViTri _t;

  @override
  TuyChonViTri doc() => _t;

  @override
  Future<void> ghi(TuyChonViTri t) async => _t = t;
}

/// Lưu ở tệp JSON nguyên tử `vi_tri.json` của `KhoLuuTru`.
final class KhoViTriTep implements KhoViTri {
  const new(this._tep);

  final TepJson _tep;

  @override
  TuyChonViTri doc() => TuyChonViTri.tuJson(_tep.duLieu);

  @override
  Future<void> ghi(TuyChonViTri t) => _tep.ghi(t.toJson());
}

/// App override bằng `KhoViTriTep` lúc khởi động.
final khoViTriProvider = Provider<KhoViTri>((_) => KhoViTriBoNho());

final tuyChonViTriProvider =
    NotifierProvider<TuyChonViTriNotifier, TuyChonViTri>(
      TuyChonViTriNotifier.new,
    );

class TuyChonViTriNotifier extends Notifier<TuyChonViTri> {
  @override
  TuyChonViTri build() => ref.read(khoViTriProvider).doc();

  void datDinhDang(DinhDangToaDo d) => _dat(state.copyWith(dinhDang: d));

  /// Ghi vị trí gần nhất (đã làm tròn) khi dời đủ xa ô cũ.
  void nhoViTri(double viDo, double kinhDo) {
    final r = lamTronLuu(viDo, kinhDo);
    if (r.viDo == state.viDoLuu && r.kinhDo == state.kinhDoLuu) return;
    _dat(state.copyWith(viDoLuu: r.viDo, kinhDoLuu: r.kinhDo));
  }

  void _dat(TuyChonViTri moi) {
    state = moi;
    ref.read(khoViTriProvider).ghi(moi).ignore();
  }
}

/// Vị trí lưu để khởi tạo `viTriBanDauProvider` của sensors.
ViTriDiaLy? viTriTuTuyChon(TuyChonViTri t) =>
    t.viDoLuu == null || t.kinhDoLuu == null
    ? null
    : ViTriDiaLy(viDo: t.viDoLuu!, kinhDo: t.kinhDoLuu!);

/// Đẩy một lần đọc vị trí sang phần dùng chung (bắc thực, WMM) và kho.
void dayViTri(WidgetRef ref, DocViTri d) {
  final n = ref.read(viTriProvider.notifier);
  final cu = n.viTri;
  if (cu == null ||
      daDoiCho(
        (viDo: cu.viDo, kinhDo: cu.kinhDo),
        d.viDo,
        d.kinhDo,
        nguongM: 500,
      )) {
    n.viTri = ViTriDiaLy(
      viDo: d.viDo,
      kinhDo: d.kinhDo,
      doCaoM: d.doCaoElip ?? 0,
    );
  }
  ref.read(tuyChonViTriProvider.notifier).nhoViTri(d.viDo, d.kinhDo);
}
