import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:security_sdk/src/domain/chuoi_ky.dart';
import 'package:security_sdk/src/domain/phien.dart';
import 'package:security_sdk/src/du_lieu/cong.dart';
import 'package:security_sdk/src/du_lieu/nen_tang_thiet_bi.dart';

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

  final ApiDinhDanh api;
  final NenTangThietBi nenTang;
  final KhoTrangThai tep;
  final CauHinhDinhDanh cauHinh;
  final int Function() _dongHo;
  Future<Result<PhienThietBi>>? _dangChay;

  /// Giờ server - giờ máy (ms), học từ lần bị từ chối `lech-gio`; chỉ trong
  /// bộ nhớ (đồng hồ máy có thể được chỉnh lại bất cứ lúc nào).
  int _lechGio = 0;

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
    final kq = await goiKy(
      'POST',
      '/v1/device/attest',
      body: {
        'thachThuc': thach,
        'chuKy': await _ky(chuoi),
        'goi': may.goi,
        'integrityToken': await nenTang.integrity(
          cauHinh.soDuAnCloud,
          requestHash(chuoi),
        ),
      },
    );
    if (kq case Err(:final failure)) return Err(failure);
    final r = (kq as Ok<PhanHoiKy>).value;
    if (!r.ok) return Err(Failure('dinhDanh.xacMinh', '${r.status} ${r.ma}'));
    final muc = MucTin.tuChuoi(r.duLieu?['mucTin']);
    final hienTai = phien ?? p;
    await _luu(
      PhienThietBi(
        thietBiId: hienTai.thietBiId,
        accessToken: hienTai.accessToken,
        hetHan: hienTai.hetHan,
        refreshToken: hienTai.refreshToken,
        mucTin: muc,
      ),
    );
    return Ok(muc);
  });

  /// Huỷ phiên cục bộ (Risk Level CRITICAL - Spec §7.3): xoá access +
  /// refresh token. Installation ID + khoá thiết bị giữ nguyên để server vẫn
  /// nhận ra máy (cấm không "rửa" được bằng cách xoá phiên); lần sau cần
  /// phiên sẽ đăng ký lại - server từ chối nếu vẫn bị cấm.
  Future<void> huyPhien() => tep.ghi({...tep.duLieu}..remove('phien'));

  /// Trạng thái thiết bị + mã REF + bản APK mới nhất (`/v1/status`).
  Future<Result<TinhTrangThietBi>> tinhTrang() => _boc(() async {
    final kq = await goiKy('GET', '/v1/status');
    if (kq case Err(:final failure)) return Err(failure);
    final r = (kq as Ok<PhanHoiKy>).value;
    if (!r.ok) return Err(Failure('dinhDanh.trangThai', '${r.status} ${r.ma}'));
    final t = TinhTrangThietBi.tuJson(r.duLieu);
    return t == null ? const Err(Failure('dinhDanh.phanHoi')) : Ok(t);
  });

  /// Gửi lô sự kiện bảo mật (Spec §7.6b, <= 50) - S4 sinh sự kiện.
  Future<Result<int>> guiSuKien(List<Map<String, Object?>> suKien) =>
      _boc(() async {
        final kq = await goiKy('POST', '/v1/events', body: {'events': suKien});
        if (kq case Err(:final failure)) return Err(failure);
        final r = (kq as Ok<PhanHoiKy>).value;
        final nhan = r.duLieu?['nhan'];
        if (!r.ok || nhan is! int) {
          return Err(Failure('dinhDanh.suKien', '${r.status} ${r.ma}'));
        }
        return Ok(nhan);
      });

  /// Yêu cầu đã ký bằng khoá thiết bị (SEC-NET, Spec §7.5): Bearer + header
  /// `x-device-id`, `x-timestamp`, `x-nonce`, `x-signature` trên chuỗi chuẩn
  /// [chuoiYeuCau]. Bị từ chối một lần vì lệch giờ -> hiệu chỉnh theo giờ
  /// server rồi ký lại; vì token / phiên -> làm mới phiên rồi gửi lại. Trả
  /// phản hồi HTTP (kể cả lỗi) - người gọi xét `status`.
  Future<Result<PhanHoiKy>> goiKy(
    String phuongThuc,
    String duongDan, {
    Map<String, Object?>? body,
  }) => _boc(() async {
    final than = body == null ? null : utf8.encode(jsonEncode(body));
    final uri = Uri.parse(duongDan);
    for (var lan = 0; ; lan++) {
      final ph = await damBaoPhien();
      if (ph case Err(:final failure)) return Err(failure);
      final p = (ph as Ok<PhienThietBi>).value;
      final ts = _dongHo() + _lechGio;
      final nonce = nonceNgauNhien();
      final chuoi = chuoiYeuCau(
        phuongThuc: phuongThuc,
        duongDan: uri.path,
        query: uri.query,
        bamThan: bamThan(than ?? const []),
        ts: ts,
        nonce: nonce,
      );
      final r = await api.goiTho(
        phuongThuc,
        duongDan,
        than: than,
        tieuDe: {
          'authorization': 'Bearer ${p.accessToken}',
          'x-device-id': p.thietBiId,
          'x-timestamp': '$ts',
          'x-nonce': nonce,
          'x-signature': await _ky(chuoi),
        },
      );
      if (lan == 0 && r.status == 401) {
        final gio = r.gioMayChu;
        if (r.ma == 'lech-gio' && gio != null) {
          _lechGio = gio - _dongHo();
          continue;
        }
        if (r.ma == 'token-sai' || r.ma == 'phien-thu-hoi') {
          // Hết hiệu lực sớm (thu hồi, khoá đổi): ép làm mới ở vòng sau.
          await _luu(
            PhienThietBi(
              thietBiId: p.thietBiId,
              accessToken: p.accessToken,
              hetHan: 0,
              refreshToken: p.refreshToken,
              mucTin: p.mucTin,
            ),
          );
          continue;
        }
      }
      return Ok(r);
    }
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
    } on LoiKetNoi catch (e) {
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
