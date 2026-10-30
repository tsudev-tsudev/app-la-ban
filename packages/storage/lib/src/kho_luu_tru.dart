import 'package:core/core.dart';
import 'package:storage/src/domain/canh_gac_crash.dart';
import 'package:storage/src/domain/co_tinh_nang.dart';
import 'package:storage/src/du_lieu/csdl.dart';
import 'package:storage/src/du_lieu/doc_tho.dart';
import 'package:storage/src/du_lieu/kho_khoa.dart';
import 'package:storage/src/du_lieu/mo_csdl.dart';
import 'package:storage/src/du_lieu/tep_json.dart';

/// Mọi thứ lưu bền của app, mở MỘT lần trước khung đầu ([KhoLuuTru.mo]).
final class KhoLuuTru {
  new _({
    required this.thuMuc,
    required this.caiDat,
    required this.laBan,
    required this.viTri,
    required this._trangThai,
    required this._co,
    required this.ketQuaCsdl,
    required this.anToan,
    required this._khoKhoa,
  });

  /// Thứ tự: canh gác crash (ghi đồng bộ, TRƯỚC mọi thứ có thể crash) ->
  /// tệp cài đặt / cờ -> CSDL (bỏ qua khi đang ghim chế độ an toàn do crash).
  static Future<KhoLuuTru> mo({
    required String phienBanApp,
    KhoKhoa khoKhoa = const KhoKhoaNenTang(),
    bool nen = true,
  }) async {
    final thuMuc = await khoKhoa.thuMucDuLieu();
    final trangThai = TepJson.mo('$thuMuc/trang_thai.json');
    final kd = batDauKhoiDong(
      TrangThaiKhoiDong.tuJson(trangThai.duLieu),
      phienBan: phienBanApp,
    );
    trangThai.ghiDongBo(kd.trangThai.toJson());

    var anToan = kd.anToan;
    var kq = const KetQuaMoCsdl();
    // Crash liên tiếp có thể do CSDL -> không mở; lỗi CSDL cũ thì thử lại.
    if (anToan != LyDoAnToan.crashLienTiep) {
      try {
        kq = await moCsdl(
          thuMuc: thuMuc,
          khoa: await khoKhoa.layKhoaCsdl(),
          nen: nen,
        );
      } on Object catch (e) {
        kq = KetQuaMoCsdl(
          loi: Failure('storage.khoa', e.runtimeType.toString()),
        );
      }
      anToan = switch (kq.loi?.code) {
        null => null,
        'storage.moiHon' => LyDoAnToan.csdlMoiHon,
        _ => LyDoAnToan.migrationLoi,
      };
    }
    return KhoLuuTru._(
      thuMuc: thuMuc,
      caiDat: TepJson.mo('$thuMuc/cai_dat.json'),
      laBan: TepJson.mo('$thuMuc/la_ban.json'),
      viTri: TepJson.mo('$thuMuc/vi_tri.json'),
      trangThai: trangThai,
      co: TepJson.mo('$thuMuc/co_tinh_nang.json'),
      ketQuaCsdl: kq,
      anToan: anToan,
      khoKhoa: khoKhoa,
    );
  }

  /// Thư mục dữ liệu không sao lưu.
  final String thuMuc;

  /// Cài đặt giao diện (settings_feature đọc / ghi).
  final TepJson caiDat;

  /// Tuỳ chọn tab La bàn (compass_feature đọc / ghi).
  final TepJson laBan;

  /// Tuỳ chọn vị trí + vị trí gần nhất làm tròn 0,1° (location_feature).
  final TepJson viTri;

  final TepJson _trangThai;
  final TepJson _co;
  final KhoKhoa _khoKhoa;

  /// Kết quả mở CSDL (lỗi -> [csdl] null).
  final KetQuaMoCsdl ketQuaCsdl;

  /// Lý do chế độ an toàn của lần chạy này (null = chạy thường).
  final LyDoAnToan? anToan;

  /// CSDL mã hoá; null ở chế độ an toàn.
  CsdlLaBan? get csdl => ketQuaCsdl.csdl;

  /// Ghi đè cờ tính năng cục bộ.
  Map<CoTinhNang, bool> get coCucBo => coTuJson(_co.duLieu);

  /// Đặt ghi đè cờ cục bộ (menu dev / chẩn đoán).
  Future<void> datCoCucBo(Map<CoTinhNang, bool> co) => _co.ghi(coRaJson(co));

  /// App đã ổn định ở lần chạy này: xoá bộ đếm crash.
  void danhDauOnDinh() => _trangThai.ghiDongBo(
    daOnDinh(TrangThaiKhoiDong.tuJson(_trangThai.duLieu)).toJson(),
  );

  /// Bỏ ghim chế độ an toàn; có hiệu lực từ lần mở app sau.
  void thoatCheDoAnToan() => _trangThai.ghiDongBo(
    thoatAnToan(TrangThaiKhoiDong.tuJson(_trangThai.duLieu)).toJson(),
  );

  /// Đọc thô điểm đã lưu để xuất khi [csdl] null (chế độ an toàn). Chạy được
  /// cả khi CSDL đang mở (đọc song song an toàn ở WAL).
  Future<List<DiemTho>> docDiemAnToan() async =>
      docDiemTho(thuMuc: thuMuc, khoa: await _khoKhoa.layKhoaCsdl());

  /// Đóng CSDL (test / khi app bị huỷ).
  Future<void> dong() async {
    await csdl?.close();
  }
}
