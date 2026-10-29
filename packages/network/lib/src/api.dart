import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Phản hồi JSON của `compass-api`. Lỗi RFC 7807 có [ma] (`code`) ổn định.
final class PhanHoiApi {
  const new(this.status, this.duLieu);

  final int status;

  /// Thân JSON (object); null khi rỗng / không phải JSON.
  final Map<String, Object?>? duLieu;

  bool get ok => status >= 200 && status < 300;

  /// Mã lỗi ngắn từ problem+json (`code`), null nếu không có.
  String? get ma => duLieu?['code'] as String?;
}

/// Lỗi tầng mạng (không kết nối được, hết giờ) - khác lỗi HTTP có [PhanHoiApi].
final class LoiMang implements Exception {
  const new(this.lyDo);

  final String lyDo;

  @override
  String toString() => 'LoiMang($lyDo)';
}

/// Gọi API JSON. S3 thêm ký request + SPKI pinning ở lớp này.
abstract interface class ApiClient {
  Future<PhanHoiApi> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  });

  Future<PhanHoiApi> get(String duongDan, {String? bearer});
}

/// Bản dùng `dart:io` HttpClient - không thêm SDK bên thứ ba.
final class ApiClientIo implements ApiClient {
  new(this.goc, {HttpClient? client, this.hetGio = const Duration(seconds: 15)})
    : _client = client ?? (HttpClient()..connectionTimeout = hetGio);

  /// Gốc API, ví dụ `https://compass-api.tsudev.com`.
  final Uri goc;
  final Duration hetGio;
  final HttpClient _client;

  /// Thân phản hồi tối đa đọc vào bộ nhớ.
  static const int thanToiDa = 64 * 1024;

  @override
  Future<PhanHoiApi> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  }) => _goi('POST', duongDan, body, bearer);

  @override
  Future<PhanHoiApi> get(String duongDan, {String? bearer}) =>
      _goi('GET', duongDan, null, bearer);

  Future<PhanHoiApi> _goi(
    String phuongThuc,
    String duongDan,
    Map<String, Object?>? body,
    String? bearer,
  ) async {
    try {
      final yc = await _client.openUrl(phuongThuc, goc.resolve(duongDan));
      yc.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearer != null) {
        yc.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }
      if (body != null) {
        final b = utf8.encode(jsonEncode(body));
        yc
          ..headers.contentType = ContentType.json
          ..contentLength = b.length
          ..add(b);
      }
      final ph = await yc.close().timeout(hetGio);
      final buf = BytesBuilder(copy: false);
      await for (final p in ph.timeout(hetGio)) {
        buf.add(p);
        if (buf.length > thanToiDa) throw const LoiMang('qua-lon');
      }
      return PhanHoiApi(ph.statusCode, giaiMaThan(buf.takeBytes()));
    } on LoiMang {
      rethrow;
    } on TimeoutException {
      throw const LoiMang('het-gio');
    } on IOException catch (e) {
      throw LoiMang(e.runtimeType.toString());
    }
  }
}

/// Thân phản hồi -> object JSON, hoặc null nếu rỗng / không phải object.
Map<String, Object?>? giaiMaThan(List<int> byte) {
  if (byte.isEmpty) return null;
  try {
    final j = jsonDecode(utf8.decode(byte));
    return j is Map<String, Object?> ? j : null;
  } on FormatException {
    return null;
  }
}
