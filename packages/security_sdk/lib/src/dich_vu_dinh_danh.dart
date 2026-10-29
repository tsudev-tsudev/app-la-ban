import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:network/network.dart';
import 'package:security_sdk/src/domain/chuoi_ky.dart';
import 'package:security_sdk/src/domain/phien.dart';
import 'package:security_sdk/src/du_lieu/nen_tang_thiet_bi.dart';
import 'package:storage/storage.dart';

/// Cấu hình theo flavor.
final class CauHinhDinhDanh {
  const new({
    required this.soDuAnCloud,
    required this.phienBanApp,
    required this.build,
    required this.ngonNgu,
  });

  /// Project number Google Cloud cho Play Integrity (không bí mật).
  final int soDuAnCloud;
  final String phienBanApp;
  final int build;
  final String Function() ngonNgu;
}

/// Định danh thiết bị + phiên (SEC-ID). Mọi lỗi trả [Failure] - app vẫn chạy
/// offline đầy đủ; server mới là nơi quyết định tin cậy.
///
/// Lưu `dinh_danh.json` (thư mục không sao lưu): Installation ID + phiên.
/// Refresh token ở đây không đủ để chiếm phiên: mỗi lần làm mới phải ký bằng
/// khoá Keystore không xuất được.
final class DichVuDinhDanh {
  new({
    required this.api,
    required this.nenTang,
    required this.tep,
    required this.cauHinh,
    int Function()? dongHo,
  }) : _dongHo = dongHo ?? _gioHeThong;

  final ApiClient api;
  final NenTangThietBi nenTang;
  final TepJson tep;
  final CauHinhDinhDanh cauHinh;
  final int Function() _dongHo;
  Future<Result<PhienThietBi>>? _dangChay;

  static int _gioHeThong() => DateTime.now().millisecondsSinceEpoch;

  /// Installation ID: sinh một lần, đổi khi cài lại / xoá dữ liệu (ID-01).
  String get installationId {
    final id = tep.duLieu['installationId'];
    if (id is String && id.length == 36) return id;
    final moi = uuidV4();
    tep.ghiDongBo({...tep.duLieu, 'installationId': moi});
    return moi;
  }

  /// Phiên đã lưu (có thể đã hết hạn access token).
  PhienThietBi? get phien => PhienThietBi.tuJson(
    tep.duLieu['phien'] is Map<String, Object?>
        ? tep.duLieu['phien']! as Map<String, Object?>
        : null,
  );

  /// Access token dùng được: đăng ký nếu chưa có, làm mới nếu sắp hết hạn.
  /// Gọi đồng thời chỉ chạy một luồng.
  Future<Result<PhienThietBi>> damBaoPhien() =>
      _dangChay ??= _damBaoPhien().whenComplete(() => _dangChay = null);

  Future<Result<PhienThietBi>> _damBaoPhien() async {
    final p = phien;
    if (p == null) return await dangKy();
    if (!p.canLamMoi(_dongHo())) return Ok(p);
    final kq = await _lamMoi(p);
    if (kq case Err(:final failure) when failure.code == 'dinhDanh.dangKyLai') {
      return await dangKy();
    }
    return kq;
  }

  /// Thách thức -> khoá -> chữ ký -> Play Integrity -> đăng ký.
  Future<Result<PhienThietBi>> dangKy() => _boc(() async {
    final id = installationId;
    final thach = await _thachThuc(id);
    final khoa = await nenTang.khoaCongKhai();
    final spki = b64url(khoa.spki);
    final chuoi = chuoiDangKy(thach, id, spki);
    final may = await nenTang.thongTin();
    final token = await nenTang.integrity(
      cauHinh.soDuAnCloud,
      requestHash(chuoi),
    );
    final r = await api.post('/v1/device/register', {
      'installationId': id,
      'khoaCongKhai': spki,
      'thachThuc': thach,
      'chuKy': await _ky(chuoi),
      'nenTang': 'android',
      'goi': may.goi,
      'integrityToken': token,
      'thongTin': {
        'heDieuHanh': may.heDieuHanh,
        'model': may.model,
        'phienBan': cauHinh.phienBanApp,
        'build': cauHinh.build,
        'ngonNgu': cauHinh.ngonNgu(),
      },
    });
    if (!r.ok) return Err(Failure('dinhDanh.dangKy', '${r.status} ${r.ma}'));
    final p = PhienThietBi.tuJson(r.duLieu);
    if (p == null) return const Err(Failure('dinhDanh.phanHoi'));
    await _luu(p);
    return Ok(p);
  });

  /// Xác minh lại (định kỳ / trước thao tác nhạy cảm): cập nhật mức tin cậy.
  Future<Result<MucTin>> xacMinhLai() => _boc(() async {
    final ph = await damBaoPhien();
    if (ph case Err(:final failure)) return Err(failure);
    final p = (ph as Ok<PhienThietBi>).value;
    final thach = await _thachThuc(installationId);
    final chuoi = chuoiXacThuc(thach, p.thietBiId);
    final may = await nenTang.thongTin();
    final r = await api.post('/v1/device/attest', {
      'thachThuc': thach,
      'chuKy': await _ky(chuoi),
      'goi': may.goi,
      'integrityToken': await nenTang.integrity(
        cauHinh.soDuAnCloud,
        requestHash(chuoi),
      ),
    }, bearer: p.accessToken);
    if (!r.ok) return Err(Failure('dinhDanh.xacMinh', '${r.status} ${r.ma}'));
    final muc = MucTin.tuChuoi(r.duLieu?['mucTin']);
    await _luu(
      PhienThietBi(
        thietBiId: p.thietBiId,
        accessToken: p.accessToken,
        hetHan: p.hetHan,
        refreshToken: p.refreshToken,
        mucTin: muc,
      ),
    );
    return Ok(muc);
  });

  Future<Result<PhienThietBi>> _lamMoi(PhienThietBi p) => _boc(() async {
    final ts = _dongHo();
    final nonce = nonceNgauNhien();
    final r = await api.post('/v1/session/refresh', {
      'refreshToken': p.refreshToken,
      'ts': ts,
      'nonce': nonce,
      'chuKy': await _ky(chuoiLamMoi(p.refreshToken, ts, nonce)),
    });
    if (!r.ok) {
      final sau = SauLamMoi.tuPhanHoi(r.status, r.ma);
      if (sau == SauLamMoi.dangKyLai) {
        await tep.ghi({...tep.duLieu}..remove('phien'));
      }
      return Err(switch (sau) {
        SauLamMoi.dangKyLai => const Failure('dinhDanh.dangKyLai'),
        SauLamMoi.biCam => const Failure('dinhDanh.biCam'),
        SauLamMoi.thuLaiSau => Failure('dinhDanh.lamMoi', '${r.status}'),
      });
    }
    final moi = PhienThietBi.tuJson(r.duLieu, thietBiId: p.thietBiId);
    if (moi == null) return const Err(Failure('dinhDanh.phanHoi'));
    await _luu(moi);
    return Ok(moi);
  });

  Future<String> _thachThuc(String id) async {
    final r = await api.post('/v1/device/challenge', {'installationId': id});
    final t = r.duLieu?['thachThuc'];
    if (!r.ok || t is! String) {
      throw _LoiBuoc('dinhDanh.thachThuc', '${r.status} ${r.ma}');
    }
    return t;
  }

  Future<String> _ky(String chuoi) async =>
      b64url(await nenTang.ky(Uint8List.fromList(utf8.encode(chuoi))));

  Future<void> _luu(PhienThietBi p) =>
      tep.ghi({...tep.duLieu, 'phien': p.toJson()});

  /// Lỗi mạng / nền tảng -> Failure có mã ổn định (không ném qua ranh giới).
  Future<Result<T>> _boc<T>(Future<Result<T>> Function() viec) async {
    try {
      return await viec();
    } on _LoiBuoc catch (e) {
      return Err(Failure(e.ma, e.chiTiet));
    } on LoiMang catch (e) {
      return Err(Failure('dinhDanh.mang', e.lyDo));
    } on Object catch (e) {
      return Err(Failure('dinhDanh.nenTang', e.runtimeType.toString()));
    }
  }
}

final class _LoiBuoc implements Exception {
  const new(this.ma, this.chiTiet);

  final String ma;
  final String chiTiet;
}
