/// Trạng thái một cảnh báo có trễ (hysteresis) và giữ tối thiểu - chống
/// nhấp nháy khi tín hiệu dao động quanh ngưỡng (vd đưa nam châm lại gần).
///
/// Quy tắc:
/// - Đang tắt: bật NGAY khi tín hiệu vượt ngưỡng bật (`vuotNguongBat`).
/// - Đang bật: chỉ tắt khi tín hiệu về dưới ngưỡng tắt (`duoiNguongTat`,
///   ngưỡng hẹp hơn ngưỡng bật) LIÊN TỤC ít nhất [TreCanhBao.choTat] VÀ đã bật
///   ít nhất [TreCanhBao.giuToiThieu].
/// - Vùng giữa hai ngưỡng: giữ nguyên trạng thái.
final class TreCanhBao {
  const new({
    this.dangBat = false,
    this.batLuc,
    this.yenTu,
    this.giuToiThieu = const Duration(seconds: 2),
    this.choTat = const Duration(milliseconds: 800),
  });

  /// Cảnh báo đang hiện.
  final bool dangBat;

  /// Thời điểm bật gần nhất (null khi tắt).
  final DateTime? batLuc;

  /// Thời điểm tín hiệu bắt đầu về dưới ngưỡng tắt liên tục (null khi chưa).
  final DateTime? yenTu;

  /// Thời gian hiện tối thiểu sau mỗi lần bật.
  final Duration giuToiThieu;

  /// Tín hiệu phải yên dưới ngưỡng tắt liên tục chừng này mới tắt.
  final Duration choTat;

  /// Trạng thái kế tiếp sau một mẫu tín hiệu lúc [luc].
  TreCanhBao capNhat({
    required bool vuotNguongBat,
    required bool duoiNguongTat,
    required DateTime luc,
  }) {
    if (!dangBat) {
      return vuotNguongBat ? _bat(luc) : this;
    }
    if (!duoiNguongTat) {
      return yenTu == null ? this : _voi(dangBat: true, batLuc: batLuc);
    }
    final yen = yenTu ?? luc;
    final duGiu = luc.difference(batLuc ?? luc) >= giuToiThieu;
    final duYen = luc.difference(yen) >= choTat;
    if (duGiu && duYen) return _voi(dangBat: false);
    return _voi(dangBat: true, batLuc: batLuc, yenTu: yen);
  }

  TreCanhBao _bat(DateTime luc) => _voi(dangBat: true, batLuc: luc);

  TreCanhBao _voi({required bool dangBat, DateTime? batLuc, DateTime? yenTu}) =>
      TreCanhBao(
        dangBat: dangBat,
        batLuc: batLuc,
        yenTu: yenTu,
        giuToiThieu: giuToiThieu,
        choTat: choTat,
      );
}

/// Bậc hiển thị ổn định (vd độ tin cậy Cao / TB / Thấp): XẤU đi thì đổi ngay
/// (an toàn trước), TỐT lên chỉ khi bậc mới giữ liên tục [choLen] và bậc cũ
/// đã hiện ít nhất [giuToiThieu] - nhãn không nhảy qua lại theo từng mẫu.
/// Bậc nhỏ hơn = xấu hơn.
final class OnDinhBac {
  const new(
    this.bac, {
    this.doiLuc,
    this.ungVien,
    this.ungVienTu,
    this.giuToiThieu = const Duration(seconds: 2),
    this.choLen = const Duration(seconds: 1),
  });

  /// Bậc đang hiển thị.
  final int bac;

  /// Lúc đổi sang [bac] (null = từ đầu).
  final DateTime? doiLuc;

  /// Bậc tốt hơn đang chờ đủ thời gian để lên.
  final int? ungVien;
  final DateTime? ungVienTu;

  final Duration giuToiThieu;
  final Duration choLen;

  OnDinhBac capNhat(int moi, DateTime luc) {
    if (moi < bac) return _voi(moi, doiLuc: luc);
    if (moi == bac) return ungVien == null ? this : _voi(bac, doiLuc: doiLuc);
    // moi > bac: chờ liên tục (về lại [bac] thì huỷ), lên tới bậc thấp nhất
    // đã thấy trong lúc chờ.
    final uv = ungVien;
    final tu = uv == null ? luc : ungVienTu!;
    final dich = uv == null ? moi : (moi < uv ? moi : uv);
    final duGiu = doiLuc == null || luc.difference(doiLuc!) >= giuToiThieu;
    if (duGiu && luc.difference(tu) >= choLen) {
      return _voi(dich, doiLuc: luc);
    }
    return _voi(bac, doiLuc: doiLuc, ungVien: dich, ungVienTu: tu);
  }

  OnDinhBac _voi(
    int bac, {
    DateTime? doiLuc,
    int? ungVien,
    DateTime? ungVienTu,
  }) => OnDinhBac(
    bac,
    doiLuc: doiLuc,
    ungVien: ungVien,
    ungVienTu: ungVienTu,
    giuToiThieu: giuToiThieu,
    choLen: choLen,
  );
}
