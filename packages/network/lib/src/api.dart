import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Phản hồi JSON của `compass-api`. Lỗi RFC 7807 có [ma] (`code`) ổn định.
final class PhanHoiApi {
  const new(this.status, this.duLieu, {this.gioMayChu});

  final int status;

  /// Thân JSON (object); null khi rỗng / không phải JSON.
  final Map<String, Object?>? duLieu;

  /// Giờ server (ms) từ header `x-server-time` - chỉ có khi server từ chối
  /// chữ ký vì lệch giờ (app hiệu chỉnh đồng hồ rồi ký lại).
  final int? gioMayChu;

  bool get ok => status >= 200 && status < 300;

  /// Mã lỗi ngắn từ problem+json (`code`), null nếu không có.
  String? get ma => duLieu?['code'] as String?;
}

/// Lỗi tầng mạng (không kết nối được, hết giờ, TLS / pin sai) - khác lỗi HTTP
/// có [PhanHoiApi]. [lyDo] = `tls` khi bắt tay TLS thất bại (gồm CA không nằm
/// trong bộ ghim).
final class LoiMang implements Exception {
  const new(this.lyDo);

  final String lyDo;

  @override
  String toString() => 'LoiMang($lyDo)';
}

/// Gọi API JSON. Ký request nằm ở security_sdk (khoá thiết bị); lớp này chỉ
/// gửi đúng byte + header được đưa (byte đã ký = byte gửi đi).
abstract interface class ApiClient {
  Future<PhanHoiApi> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  });

  Future<PhanHoiApi> get(String duongDan, {String? bearer});

  /// Gửi nguyên văn [than] (JSON đã mã hoá) với [tieuDe] thêm.
  Future<PhanHoiApi> goi(
    String phuongThuc,
    String duongDan, {
    List<int>? than,
    Map<String, String> tieuDe = const {},
  });
}

/// SecurityContext CHỈ tin các CA gốc [pem] (SEC-NET: SPKI pinning ở mức CA -
/// dart:io chỉ lộ chứng chỉ lá nên ghim bằng neo tin cậy). CA người dùng / CA
/// hệ thống khác không được tin (`SecurityContext()` mặc định không nạp kho CA
/// hệ thống).
SecurityContext nguCanhGhim(Iterable<String> pem) {
  final ds = pem.toList();
  if (ds.isEmpty) throw ArgumentError('cần ít nhất một CA gốc');
  return SecurityContext()
    ..setTrustedCertificatesBytes(utf8.encode(ds.join('\n')));
}

/// Bản dùng `dart:io` HttpClient - không thêm SDK bên thứ ba.
final class ApiClientIo implements ApiClient {
  /// [gocGhim]: PEM các CA gốc được tin (null = kho CA hệ thống - chỉ dùng
  /// cho Remote Config vì gói đã ký số, và cho `http://` ở flavor dev).
  new(
    this.goc, {
    HttpClient? client,
    Iterable<String>? gocGhim,
    this.hetGio = const Duration(seconds: 15),
  }) : _client = client ?? _taoClient(gocGhim, hetGio);

  /// Gốc API, ví dụ `https://compass-api.tsudev.com`.
  final Uri goc;
  final Duration hetGio;
  HttpClient _client;

  /// Thân phản hồi tối đa đọc vào bộ nhớ.
  static const int thanToiDa = 64 * 1024;

  static HttpClient _taoClient(Iterable<String>? gocGhim, Duration hetGio) =>
      HttpClient(context: gocGhim == null ? null : nguCanhGhim(gocGhim))
        ..connectionTimeout = hetGio;

  /// Đổi bộ CA ghim (xoay pin từ Remote Config) - kết nối đang mở vẫn chạy
  /// xong, yêu cầu sau dùng bộ mới.
  void doiGhim(Iterable<String> gocGhim) {
    final cu = _client;
    _client = _taoClient(gocGhim, hetGio);
    cu.close();
  }

  @override
  Future<PhanHoiApi> post(
    String duongDan,
    Map<String, Object?> body, {
    String? bearer,
  }) => goi(
    'POST',
    duongDan,
    than: utf8.encode(jsonEncode(body)),
    tieuDe: {HttpHeaders.authorizationHeader: ?_bearer(bearer)},
  );

  @override
  Future<PhanHoiApi> get(String duongDan, {String? bearer}) => goi(
    'GET',
    duongDan,
    tieuDe: {HttpHeaders.authorizationHeader: ?_bearer(bearer)},
  );

  static String? _bearer(String? b) => b == null ? null : 'Bearer $b';

  @override
  Future<PhanHoiApi> goi(
    String phuongThuc,
    String duongDan, {
    List<int>? than,
    Map<String, String> tieuDe = const {},
  }) async {
    try {
      final yc = await _client.openUrl(phuongThuc, goc.resolve(duongDan));
      yc.headers.set(HttpHeaders.acceptHeader, 'application/json');
      tieuDe.forEach(yc.headers.set);
      if (than != null) {
        yc
          ..headers.contentType = ContentType.json
          ..contentLength = than.length
          ..add(than);
      }
      final ph = await yc.close().timeout(hetGio);
      final buf = BytesBuilder(copy: false);
      await for (final p in ph.timeout(hetGio)) {
        buf.add(p);
        if (buf.length > thanToiDa) throw const LoiMang('qua-lon');
      }
      return PhanHoiApi(
        ph.statusCode,
        giaiMaThan(buf.takeBytes()),
        gioMayChu: int.tryParse(ph.headers.value('x-server-time') ?? ''),
      );
    } on LoiMang {
      rethrow;
    } on TimeoutException {
      throw const LoiMang('het-gio');
    } on HandshakeException {
      throw const LoiMang('tls');
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
