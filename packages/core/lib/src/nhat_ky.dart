import 'dart:developer' as developer;

/// Che dữ liệu nhạy cảm trước khi ghi log (SEC-APP-STORAGE: không log token /
/// tọa độ chính xác ở release): JWT, `Bearer ...`, refresh token / chữ ký
/// base64url dài, tọa độ thập phân (làm tròn 2 chữ số ~ 1 km).
String cheNhatKy(String s) => s
    .replaceAll(_jwt, '<jwt>')
    .replaceAll(_bearer, 'Bearer <an>')
    .replaceAllMapped(_toaDo, (m) => '${m[1]}${m[2]}.${m[3]}~')
    .replaceAll(_chuoiDai, '<an>');

final _jwt = RegExp(r'eyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{8,}');
final _bearer = RegExp(r'Bearer\s+\S+', caseSensitive: false);

/// `-?dd.ddd...` (>= 3 chữ số thập phân) -> giữ 2 chữ số.
final _toaDo = RegExp(r'(-?)(\d{1,3})\.(\d{2})\d+');

/// Chuỗi base64url / hex >= 32 ký tự (token, chữ ký, khoá).
final _chuoiDai = RegExp(r'[A-Za-z0-9_\-+/]{32,}={0,2}');

/// Nơi ghi log - test thay để bắt nội dung.
typedef GhiNhatKy = void Function(String noiDung, {String ten});

/// Logger chung. [che] = true ở release (app đặt theo `kReleaseMode`): mọi
/// dòng qua [cheNhatKy] trước khi ghi.
final class NhatKy {
  const new(this.ten, {this.che = true, this._ghi});

  final String ten;
  final bool che;
  final GhiNhatKy? _ghi;

  void call(String noiDung) {
    final s = che ? cheNhatKy(noiDung) : noiDung;
    final g = _ghi;
    if (g != null) {
      g(s, ten: ten);
    } else {
      developer.log(s, name: ten);
    }
  }
}
