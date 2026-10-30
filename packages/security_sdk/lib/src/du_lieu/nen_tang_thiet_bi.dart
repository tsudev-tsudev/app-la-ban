import 'package:flutter/services.dart';
import 'package:security_sdk/src/domain/rasp.dart';

/// Thông tin máy gửi khi đăng ký (không định danh phần cứng).
typedef ThongTinMay = ({String model, String heDieuHanh, String goi});

/// Khoá công khai thiết bị (SPKI DER) + nơi giữ khoá riêng.
typedef KhoaThietBi = ({Uint8List spki, String mucBaoMat});

/// Phần nền tảng: khoá Keystore, chữ ký, Play Integrity.
abstract interface class NenTangThietBi {
  Future<KhoaThietBi> khoaCongKhai();

  /// Chữ ký ECDSA P-256 SHA-256 dạng DER.
  Future<Uint8List> ky(Uint8List duLieu);

  /// Token Play Integrity Standard; null khi máy không hỗ trợ (không Play
  /// Store, lỗi tạm) - server xếp 'unverified'.
  Future<String?> integrity(int soDuAn, String requestHash);

  Future<ThongTinMay> thongTin();

  Future<void> xoaKhoa();

  /// Kiểm tra môi trường native (Kotlin + NDK, SEC-APP APP-02 / APP-03).
  Future<KetQuaNative> kiemTraMoiTruong();

  /// FLAG_SECURE: chặn chụp / quay màn hình + che ảnh xem trước ở app
  /// switcher khi đang ở màn nhạy cảm (SEC-APP-STORAGE).
  Future<void> cheManHinh({required bool bat});
}

/// Kênh tới ThietBiPlugin (android/ của gói này).
final class NenTangThietBiKenh implements NenTangThietBi {
  const new();

  static const _kenh = MethodChannel('la_ban/thiet_bi');

  @override
  Future<KhoaThietBi> khoaCongKhai() async {
    final m = await _kenh.invokeMapMethod<String, Object?>('khoaCongKhai');
    final spki = m?['spki'];
    if (spki is! Uint8List) throw PlatformException(code: 'khoa.rong');
    return (spki: spki, mucBaoMat: m?['mucBaoMat'] as String? ?? 'khac');
  }

  @override
  Future<Uint8List> ky(Uint8List duLieu) async {
    final k = await _kenh.invokeMethod<Uint8List>('ky', {'duLieu': duLieu});
    if (k == null) throw PlatformException(code: 'ky.rong');
    return k;
  }

  @override
  Future<String?> integrity(int soDuAn, String requestHash) async {
    try {
      return await _kenh.invokeMethod<String>('integrity', {
        'soDuAn': soDuAn,
        'requestHash': requestHash,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<ThongTinMay> thongTin() async {
    final m = await _kenh.invokeMapMethod<String, Object?>('thongTin');
    return (
      model: m?['model'] as String? ?? '',
      heDieuHanh: m?['heDieuHanh'] as String? ?? '',
      goi: m?['goi'] as String? ?? '',
    );
  }

  @override
  Future<void> xoaKhoa() => _kenh.invokeMethod<void>('xoaKhoa');

  @override
  Future<KetQuaNative> kiemTraMoiTruong() async {
    try {
      return KetQuaNative.tuMap(
        await _kenh.invokeMapMethod<Object?, Object?>('moiTruong'),
      );
    } on PlatformException {
      return const KetQuaNative(coNative: false);
    }
  }

  @override
  Future<void> cheManHinh({required bool bat}) async {
    try {
      await _kenh.invokeMethod<void>('cheManHinh', {'bat': bat});
    } on PlatformException {
      // Không có Activity (đang nền) - lần hiện màn sau gọi lại.
    } on MissingPluginException {
      // Test / nền tảng chưa hỗ trợ.
    }
  }
}

/// Mở trang của La bàn (`https://compass.tsudev.com/...`) bằng trình duyệt
/// (trang tải bản mới, chính sách) hoặc thư tới `privacy@tsudev.com`. false
/// khi máy không có ứng dụng phù hợp / URL ngoài danh sách.
Future<bool> moTrangLaBan(Uri url) async {
  try {
    return await const MethodChannel('la_ban/thiet_bi')
            .invokeMethod<bool>('moTrang', {'url': url.toString()}) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
