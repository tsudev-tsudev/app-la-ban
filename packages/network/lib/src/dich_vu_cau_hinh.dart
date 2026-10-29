import 'dart:async';

import 'package:network/src/api.dart';
import 'package:network/src/domain/cau_hinh_tu_xa.dart';

/// Nơi lưu gói Remote Config (nguyên văn đã ký - đọc lại thì kiểm lại).
abstract interface class KhoGoiCauHinh {
  String? doc();

  Future<void> ghi(String goi);
}

/// Remote Config ký số (SEC-NET): tải `/v1/config` bằng kho CA hệ thống
/// (gói tự mang chữ ký nên kênh tải không cần ghim - nhờ vậy xoay pin được kể
/// cả khi CA đổi bất ngờ), kiểm Ed25519, lưu, báo [khiDoi]. Gói sai chữ ký /
/// hết hạn / cũ hơn -> giữ cấu hình đang có.
final class DichVuCauHinh {
  new({
    required this.api,
    required this.kho,
    required this.khoa,
    this.khiDoi,
    int Function()? dongHo,
  }) : _dongHo = dongHo ?? _gioHeThong {
    final raw = kho.doc();
    if (raw != null) {
      final kq = docGoiCauHinh(raw, khoa: khoa, bayGio: _dongHo());
      if (kq is GoiHopLe) _hienTai = kq.cauHinh;
    }
  }

  final ApiClient api;
  final KhoGoiCauHinh kho;
  final Map<String, String> khoa;
  final void Function(CauHinhTuXa?)? khiDoi;
  final int Function() _dongHo;
  CauHinhTuXa? _hienTai;

  static int _gioHeThong() => DateTime.now().millisecondsSinceEpoch;

  /// Cấu hình còn hạn; null = dùng mặc định đóng gói.
  CauHinhTuXa? get hienTai {
    final ch = _hienTai;
    return ch != null && ch.het > _dongHo() ? ch : null;
  }

  /// PEM CA gốc đang được tin cho kênh API.
  List<String> get gocTinCay => hienTai?.gocHieuLuc ?? gocMacDinh;

  /// Tải + kiểm gói mới. Trả lý do (`ok`, `khong-co`, `mang`, `http-<mã>`,
  /// hoặc lý do từ chối của [docGoiCauHinh]).
  Future<String> lamMoi() async {
    final PhanHoiApi r;
    try {
      r = await api.goi('GET', '/v1/config');
    } on LoiMang {
      return 'mang';
    }
    if (r.status == 404) return 'khong-co';
    final duLieu = r.duLieu;
    if (!r.ok || duLieu == null) return 'http-${r.status}';
    final raw = _jsonGoi(duLieu);
    final kq = docGoiCauHinh(
      raw,
      khoa: khoa,
      bayGio: _dongHo(),
      phatHanhDangGiu: _hienTai?.phatHanh,
    );
    switch (kq) {
      case GoiBiTuChoi(:final lyDo):
        return lyDo;
      case GoiHopLe(:final cauHinh):
        if (cauHinh.phatHanh == _hienTai?.phatHanh) return 'ok';
        _hienTai = cauHinh;
        await kho.ghi(raw);
        khiDoi?.call(cauHinh);
        return 'ok';
    }
  }

  /// Chỉ 3 trường của gói, theo thứ tự cố định (chữ ký nằm trên `duLieu`
  /// nên dựng lại JSON không ảnh hưởng kiểm chứng).
  static String _jsonGoi(Map<String, Object?> d) =>
      '{"kid":${_chuoi(d['kid'])},"duLieu":${_chuoi(d['duLieu'])},'
      '"chuKy":${_chuoi(d['chuKy'])}}';

  static String _chuoi(Object? v) =>
      v is String && RegExp(r'^[A-Za-z0-9_-]{1,40000}$').hasMatch(v)
      ? '"$v"'
      : 'null';
}
