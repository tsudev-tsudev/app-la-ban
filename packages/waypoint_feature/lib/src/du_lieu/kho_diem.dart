import 'dart:async';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:storage/storage.dart';
import 'package:waypoint_feature/src/domain/diem_moc.dart';

/// Ảnh đã lưu của một điểm (JPEG).
@immutable
final class AnhDiemMoc {
  const new({
    required this.id,
    required this.duLieu,
    required this.rong,
    required this.cao,
  });

  final int id;
  final Uint8List duLieu;
  final int rong;
  final int cao;
}

/// Ảnh mới chưa lưu (từ bộ chọn ảnh nền tảng).
typedef AnhMoi = ({Uint8List duLieu, int rong, int cao});

/// Số ảnh tối đa mỗi điểm.
const anhToiDa = 6;

/// Nơi lưu điểm. App dùng [KhoDiemDrift]; test / golden dùng [KhoDiemBoNho].
abstract interface class KhoDiem {
  /// Mọi điểm, mới tạo trước; phát lại khi có thay đổi.
  Stream<List<DiemMoc>> theoDoi();

  Future<List<DiemMoc>> tatCa();

  /// Thêm hoặc cập nhật theo id (KHÔNG xoá dòng cũ -> ảnh giữ nguyên).
  Future<void> luu(DiemMoc d);

  /// Ghi nhiều điểm trong một transaction.
  Future<void> luuNhieu(List<DiemMoc> ds);

  /// Xoá điểm (ảnh đi theo).
  Future<void> xoa(String id);

  Stream<List<AnhDiemMoc>> theoDoiAnh(String diemId);

  Future<void> themAnh(String diemId, AnhMoi a, {required int luc});

  Future<void> xoaAnh(int id);
}

/// Kho trên CSDL mã hoá (`packages/storage`).
final class KhoDiemDrift implements KhoDiem {
  const new(this._db);

  final CsdlLaBan _db;

  static DiemMoc _tu(DongDiem d) => DiemMoc(
    id: d.id,
    ten: d.ten,
    viDo: d.viDo,
    kinhDo: d.kinhDo,
    caoDo: d.caoDo,
    ghiChu: d.ghiChu,
    taoLuc: d.taoLuc,
    suaLuc: d.suaLuc,
  );

  static DiemCompanion _ra(DiemMoc d) => DiemCompanion.insert(
    id: d.id,
    ten: d.ten,
    viDo: d.viDo,
    kinhDo: d.kinhDo,
    caoDo: Value(d.caoDo),
    ghiChu: Value(d.ghiChu),
    taoLuc: d.taoLuc,
    suaLuc: d.suaLuc,
  );

  SimpleSelectStatement<$DiemTable, DongDiem> get _hoi => _db.select(_db.diem)
    ..orderBy([
      (d) => OrderingTerm.desc(d.taoLuc),
      (d) => OrderingTerm.asc(d.id),
    ]);

  @override
  Stream<List<DiemMoc>> theoDoi() =>
      _hoi.watch().map((ds) => ds.map(_tu).toList());

  @override
  Future<List<DiemMoc>> tatCa() async => (await _hoi.get()).map(_tu).toList();

  @override
  Future<void> luu(DiemMoc d) =>
      _db.into(_db.diem).insertOnConflictUpdate(_ra(d));

  @override
  Future<void> luuNhieu(List<DiemMoc> ds) => _db.batch((b) {
    for (final d in ds) {
      b.insert(_db.diem, _ra(d), onConflict: DoUpdate((_) => _ra(d)));
    }
  });

  @override
  Future<void> xoa(String id) =>
      (_db.delete(_db.diem)..where((d) => d.id.equals(id))).go();

  @override
  Stream<List<AnhDiemMoc>> theoDoiAnh(String diemId) =>
      (_db.select(_db.anhDiem)
            ..where((a) => a.diemId.equals(diemId))
            ..orderBy([(a) => OrderingTerm.asc(a.id)]))
          .watch()
          .map(
            (ds) => [
              for (final a in ds)
                AnhDiemMoc(
                  id: a.id,
                  duLieu: a.duLieu,
                  rong: a.rong,
                  cao: a.cao,
                ),
            ],
          );

  @override
  Future<void> themAnh(String diemId, AnhMoi a, {required int luc}) => _db
      .into(_db.anhDiem)
      .insert(
        AnhDiemCompanion.insert(
          diemId: diemId,
          duLieu: a.duLieu,
          rong: a.rong,
          cao: a.cao,
          taoLuc: luc,
        ),
      );

  @override
  Future<void> xoaAnh(int id) =>
      (_db.delete(_db.anhDiem)..where((a) => a.id.equals(id))).go();
}

/// Kho trong bộ nhớ (test, golden).
final class KhoDiemBoNho implements KhoDiem {
  new([Iterable<DiemMoc> ds = const []]) {
    for (final d in ds) {
      _diem[d.id] = d;
    }
  }

  final _diem = <String, DiemMoc>{};
  final _anh = <String, List<AnhDiemMoc>>{};
  final _doi = StreamController<void>.broadcast();
  var _idAnh = 0;

  List<DiemMoc> _ds() => _diem.values.toList()
    ..sort((a, b) {
      final c = b.taoLuc.compareTo(a.taoLuc);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  Stream<T> _phat<T>(T Function() lay) async* {
    yield lay();
    yield* _doi.stream.map((_) => lay());
  }

  @override
  Stream<List<DiemMoc>> theoDoi() => _phat(_ds);

  @override
  Future<List<DiemMoc>> tatCa() async => _ds();

  @override
  Future<void> luu(DiemMoc d) async {
    _diem[d.id] = d;
    _doi.add(null);
  }

  @override
  Future<void> luuNhieu(List<DiemMoc> ds) async {
    for (final d in ds) {
      _diem[d.id] = d;
    }
    _doi.add(null);
  }

  @override
  Future<void> xoa(String id) async {
    _diem.remove(id);
    _anh.remove(id);
    _doi.add(null);
  }

  @override
  Stream<List<AnhDiemMoc>> theoDoiAnh(String diemId) =>
      _phat(() => List.of(_anh[diemId] ?? const <AnhDiemMoc>[]));

  @override
  Future<void> themAnh(String diemId, AnhMoi a, {required int luc}) async {
    (_anh[diemId] ??= []).add(
      AnhDiemMoc(id: ++_idAnh, duLieu: a.duLieu, rong: a.rong, cao: a.cao),
    );
    _doi.add(null);
  }

  @override
  Future<void> xoaAnh(int id) async {
    for (final ds in _anh.values) {
      ds.removeWhere((a) => a.id == id);
    }
    _doi.add(null);
  }
}
