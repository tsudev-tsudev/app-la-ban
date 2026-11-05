import 'package:app_shell/src/luu_tru.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:location_feature/location_feature.dart';
import 'package:storage/storage.dart';
import 'package:waypoint_feature/waypoint_feature.dart';

/// Nối tab Điểm với phần còn lại của app (tính năng không gọi nhau): CSDL /
/// chế độ an toàn, cờ `chiaSe`, vị trí + quyền + định dạng toạ độ của
/// location_feature.
List<Override> noiDiem(KhoLuuTru? kho) => [
  khoDiemProvider.overrideWith((ref) {
    final db = ref.watch(khoLuuTruProvider)?.csdl;
    return db == null ? null : KhoDiemDrift(db);
  }),
  if (kho != null)
    docDiemAnToanProvider.overrideWithValue(
      () async => [
        for (final d in await kho.docDiemAnToan())
          DiemMoc(
            id: d.id,
            ten: d.ten,
            viDo: d.viDo,
            kinhDo: d.kinhDo,
            caoDo: d.caoDo,
            ghiChu: d.ghiChu,
            taoLuc: d.taoLuc,
            suaLuc: d.suaLuc,
          ),
      ],
    ),
  choPhepChiaSeProvider.overrideWith(
    (ref) => ref.watch(coTinhNangProvider)[CoTinhNang.chiaSe]!,
  ),
  viTriDiemProvider.overrideWith(viTriChoDiem),
  xinQuyenViTriDiemProvider.overrideWith(
    (ref) =>
        () => ref.read(quyenViTriProvider.notifier).xin(),
  ),
  dinhDangToaDoDiemProvider.overrideWith((ref) {
    final dd = ref.watch(tuyChonViTriProvider.select((t) => t.dinhDang));
    return (vi, kinh) => dinhDangToaDo(dd, vi, kinh) ?? dinhDangDD(vi, kinh);
  }),
];

/// Trạng thái vị trí cho tab Điểm từ quyền + luồng GPS của location_feature;
/// cao độ trên mực biển (nền tảng hoặc elipxoit - geoid EGM96).
TrangThaiViTri viTriChoDiem(Ref ref) {
  final q = ref.watch(quyenViTriProvider).value;
  if (q == null) return const ViTriDangCho();
  if (!q.duocPhep) return const ViTriChuaCoQuyen();
  final d = ref.watch(docViTriProvider).value;
  if (d == null) return const ViTriDangCho();
  final geoid = ref.watch(taiNguyenViTriProvider).value?.geoid;
  return ViTriCo((
    viDo: d.viDo,
    kinhDo: d.kinhDo,
    caoDo: doCaoMucBien(d, geoid),
    saiSoM: d.doChinhXacNgang,
  ));
}
