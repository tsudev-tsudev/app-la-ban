import 'dart:convert';
import 'dart:typed_data';

import 'package:waypoint_feature/waypoint_feature.dart';

/// M2b bước 3 (QUYET_DINH Q56, Q66): gói dữ liệu bản miễn phí -> La bàn Pro.
/// Hàm THUẦN - không đọc kho, không gọi nền tảng.

/// Định danh định dạng gói chuyển (không đổi).
const dinhDangChuyenPro = 'la-ban-chuyen-pro';

/// Tăng khi đổi cấu trúc gói; bản đọc chỉ nhận <= số này.
const phienBanChuyenPro = 1;

/// Định dạng tệp "Xuất dữ liệu cá nhân" (Quyền riêng tư) - app Pro nhận cả
/// tệp này làm đường dự phòng (không có ảnh / vùng offline).
const dinhDangXuatCaNhan = 'la-ban-du-lieu-ca-nhan';

/// Trần an toàn khi đọc gói (gói hỏng / cố ý phình không làm treo app).
const diemChuyenToiDa = 20000;
const anhChuyenToiDa = 6;
const int byteAnhToiDa = 4 * 1024 * 1024;
const vungChuyenToiDa = 50;

/// Một vùng offline: chỉ chuyển ĐỊNH NGHĨA (tile nằm trong CSDL MapLibre của
/// từng app) - app Pro tải lại khi người dùng bấm.
typedef VungChuyen = ({
  String ten,
  double bac,
  double nam,
  double dong,
  double tay,
  int zMin,
  int zMax,
  bool tongQuan,
});

/// Ảnh của một điểm (JPEG đã bỏ EXIF ở bản miễn phí).
typedef AnhChuyen = ({
  String diemId,
  Uint8List duLieu,
  int rong,
  int cao,
  int taoLuc,
});

/// Cài đặt được chuyển: chỉ lựa chọn giao diện. Đồng ý xử lý dữ liệu và báo
/// cáo sự cố KHÔNG chuyển - app Pro hỏi lại (đồng ý gắn với từng app).
typedef CaiDatChuyen = ({
  String? ngonNgu,
  String? cheDo,
  bool? bacThuc,
  bool? rung,
  String? dinhDangToaDo,
});

/// Gói đã đọc và kiểm.
final class GoiChuyen {
  const new({
    required this.diem,
    required this.anh,
    required this.vung,
    required this.caiDat,
    required this.boQua,
    required this.coAnhVung,
  });

  final List<DiemMoc> diem;
  final List<AnhChuyen> anh;
  final List<VungChuyen> vung;
  final CaiDatChuyen caiDat;

  /// Số mục bị bỏ vì sai / vượt trần.
  final int boQua;

  /// false: tệp "Xuất dữ liệu cá nhân" (không có ảnh / vùng offline).
  final bool coAnhVung;

  bool get rong =>
      diem.isEmpty &&
      vung.isEmpty &&
      caiDat ==
          (
            ngonNgu: null,
            cheDo: null,
            bacThuc: null,
            rung: null,
            dinhDangToaDo: null,
          );
}

/// Dựng gói JSON từ dữ liệu thô của bản miễn phí.
Map<String, Object?> taoGoiChuyen({
  required String phienBanApp,
  required DateTime luc,
  required List<DiemMoc> diem,
  required List<AnhChuyen> anh,
  required List<VungChuyen> vung,
  required Map<String, Object?> caiDat,
  required Map<String, Object?> tuyChonLaBan,
  required Map<String, Object?> viTri,
}) => {
  'dinhDang': dinhDangChuyenPro,
  'phienBanDinhDang': phienBanChuyenPro,
  'taoLuc': luc.toUtc().toIso8601String(),
  'phienBanApp': phienBanApp,
  'caiDat': {'ngonNgu': ?caiDat['ngonNgu'], 'cheDo': ?caiDat['cheDo']},
  'tuyChonLaBan': {
    'bacThuc': ?tuyChonLaBan['bacThuc'],
    'rung': ?tuyChonLaBan['rung'],
  },
  // Chỉ định dạng toạ độ - KHÔNG chuyển vị trí gần nhất.
  'viTri': {'dinhDang': ?viTri['dinhDang']},
  'diem': [
    for (final d in diem)
      {
        'id': d.id,
        'ten': d.ten,
        'viDo': d.viDo,
        'kinhDo': d.kinhDo,
        'caoDo': d.caoDo,
        'ghiChu': d.ghiChu,
        'taoLuc': d.taoLuc,
        'suaLuc': d.suaLuc,
      },
  ],
  'anh': [
    for (final a in anh)
      {
        'diemId': a.diemId,
        'rong': a.rong,
        'cao': a.cao,
        'taoLuc': a.taoLuc,
        'duLieu': base64.encode(a.duLieu),
      },
  ],
  'vung': [
    for (final v in vung)
      {
        'ten': v.ten,
        'bac': v.bac,
        'nam': v.nam,
        'dong': v.dong,
        'tay': v.tay,
        'zMin': v.zMin,
        'zMax': v.zMax,
        'tongQuan': v.tongQuan,
      },
  ],
};

/// Mốc thời gian: số ms (gói chuyển) hoặc chuỗi ISO 8601 (tệp xuất cá nhân).
int? _moc(Object? v) => switch (v) {
  final int n => n,
  final String s => DateTime.tryParse(s)?.toUtc().millisecondsSinceEpoch,
  _ => null,
};

double? _so(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

String? _trong(Object? v, Iterable<String> cho) =>
    v is String && cho.contains(v) ? v : null;

const _ngonNgu = {'heThong', 'vi', 'en'};
const _cheDo = {'heThong', 'sang', 'toi'};
const _dinhDangToaDo = {'dd', 'dms', 'utm', 'mgrs'};

Map<String, Object?> _bang(Object? v) =>
    v is Map ? v.cast<String, Object?>() : const {};

List<Object?> _ds(Object? v) => v is List ? v : const [];

/// Đọc + kiểm gói (bytes UTF-8 JSON). Sai định dạng / phiên bản mới hơn ->
/// [FormatException]. Điểm / ảnh / vùng sai bị bỏ (đếm ở [GoiChuyen.boQua]).
GoiChuyen docGoiChuyen(Uint8List byte) {
  final Object? j;
  try {
    j = jsonDecode(utf8.decode(byte));
  } on FormatException {
    throw const FormatException('chuyen.json');
  }
  if (j is! Map) throw const FormatException('chuyen.json');
  final goc = j.cast<String, Object?>();
  final dd = goc['dinhDang'];
  final coAnhVung = dd == dinhDangChuyenPro;
  if (!coAnhVung && dd != dinhDangXuatCaNhan) {
    throw const FormatException('chuyen.dinhDang');
  }
  final pb = goc['phienBanDinhDang'];
  if (pb is! int || pb < 1 || (coAnhVung && pb > phienBanChuyenPro)) {
    throw const FormatException('chuyen.phienBan');
  }
  var boQua = 0;

  final diem = <DiemMoc>[];
  final daCo = <String>{};
  for (final o in _ds(goc['diem'])) {
    final m = _bang(o);
    final id = m['id'];
    final ten = m['ten'];
    final viDo = _so(m['viDo']);
    final kinhDo = _so(m['kinhDo']);
    final caoDo = _so(m['caoDo']);
    final ghiChu = m['ghiChu'] is String ? m['ghiChu']! as String : '';
    final tao = _moc(m['taoLuc']);
    final sua = _moc(m['suaLuc']) ?? tao;
    final hopLe =
        id is String &&
        id.isNotEmpty &&
        id.length <= 64 &&
        ten is String &&
        tao != null &&
        sua != null &&
        diem.length < diemChuyenToiDa &&
        kiemDiem(
          ten: ten,
          viDo: viDo,
          kinhDo: kinhDo,
          caoDo: caoDo,
          ghiChu: ghiChu,
        ).isEmpty &&
        daCo.add(id);
    if (!hopLe) {
      boQua++;
      continue;
    }
    diem.add(
      DiemMoc(
        id: id,
        ten: ten.trim(),
        viDo: viDo!,
        kinhDo: kinhDo!,
        caoDo: caoDo,
        ghiChu: ghiChu,
        taoLuc: tao,
        suaLuc: sua,
      ),
    );
  }

  final anh = <AnhChuyen>[];
  final demAnh = <String, int>{};
  for (final o in _ds(goc['anh'])) {
    final m = _bang(o);
    final diemId = m['diemId'];
    final rong = m['rong'];
    final cao = m['cao'];
    final tao = _moc(m['taoLuc']);
    Uint8List? du;
    if (m['duLieu'] case final String s
        when s.length <= byteAnhToiDa * 4 ~/ 3 + 4) {
      try {
        du = base64.decode(s);
      } on FormatException {
        du = null;
      }
    }
    final hopLe =
        diemId is String &&
        daCo.contains(diemId) &&
        rong is int &&
        cao is int &&
        rong > 0 &&
        cao > 0 &&
        tao != null &&
        du != null &&
        du.isNotEmpty &&
        du.length <= byteAnhToiDa &&
        (demAnh[diemId] ?? 0) < anhChuyenToiDa;
    if (!hopLe) {
      boQua++;
      continue;
    }
    demAnh[diemId] = (demAnh[diemId] ?? 0) + 1;
    anh.add((diemId: diemId, duLieu: du, rong: rong, cao: cao, taoLuc: tao));
  }

  final vung = <VungChuyen>[];
  for (final o in _ds(goc['vung'])) {
    final m = _bang(o);
    final ten = m['ten'];
    final bac = _so(m['bac']);
    final nam = _so(m['nam']);
    final dong = _so(m['dong']);
    final tay = _so(m['tay']);
    final zMin = m['zMin'];
    final zMax = m['zMax'];
    final hopLe =
        ten is String &&
        ten.length <= 120 &&
        bac != null &&
        nam != null &&
        dong != null &&
        tay != null &&
        bac.abs() <= 90 &&
        nam.abs() <= 90 &&
        nam <= bac &&
        dong.abs() <= 180 &&
        tay.abs() <= 180 &&
        zMin is int &&
        zMax is int &&
        zMin >= 0 &&
        zMin <= zMax &&
        zMax <= 22 &&
        vung.length < vungChuyenToiDa;
    if (!hopLe) {
      boQua++;
      continue;
    }
    vung.add((
      ten: ten,
      bac: bac,
      nam: nam,
      dong: dong,
      tay: tay,
      zMin: zMin,
      zMax: zMax,
      tongQuan: m['tongQuan'] == true,
    ));
  }

  final cd = _bang(goc['caiDat']);
  final lb = _bang(goc['tuyChonLaBan']);
  final vt = _bang(goc['viTri']);
  return GoiChuyen(
    diem: diem,
    anh: anh,
    vung: vung,
    caiDat: (
      ngonNgu: _trong(cd['ngonNgu'], _ngonNgu),
      cheDo: _trong(cd['cheDo'], _cheDo),
      bacThuc: lb['bacThuc'] is bool ? lb['bacThuc']! as bool : null,
      rung: lb['rung'] is bool ? lb['rung']! as bool : null,
      dinhDangToaDo: _trong(vt['dinhDang'], _dinhDangToaDo),
    ),
    boQua: boQua,
    coAnhVung: coAnhVung,
  );
}

/// Kế hoạch ghi vào app Pro.
typedef KeHoachNhapPro = ({
  List<DiemMoc> them,
  List<DiemMoc> capNhat,
  int trung,

  /// Ảnh chỉ đi theo điểm MỚI (điểm đã có giữ ảnh của nó - nhập lại không
  /// nhân đôi ảnh).
  List<AnhChuyen> anh,
});

/// Ghép gói với điểm đã có trong app Pro theo id: chưa có -> thêm; có mà bản
/// gửi sửa SAU -> cập nhật; còn lại giữ nguyên. Nhập lại cùng gói = không đổi.
KeHoachNhapPro keHoachNhapPro(
  GoiChuyen g, {
  required Map<String, DiemMoc> coSan,
}) {
  final them = <DiemMoc>[];
  final capNhat = <DiemMoc>[];
  var trung = 0;
  for (final d in g.diem) {
    final cu = coSan[d.id];
    if (cu == null) {
      them.add(d);
    } else if (cu == d || d.suaLuc <= cu.suaLuc) {
      trung++;
    } else {
      capNhat.add(d);
    }
  }
  final moi = {for (final d in them) d.id};
  return (
    them: them,
    capNhat: capNhat,
    trung: trung,
    anh: [
      for (final a in g.anh)
        if (moi.contains(a.diemId)) a,
    ],
  );
}
