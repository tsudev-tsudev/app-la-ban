import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:waypoint_feature/src/domain/diem_moc.dart';
import 'package:waypoint_feature/src/domain/token_chia_se.dart';
import 'package:waypoint_feature/src/providers.dart';

/// Khoảng cách dễ đọc: < 1 km theo mét (làm tròn 1 m, từ 100 m làm tròn
/// 10 m), còn lại km 1 chữ số.
String khoangCach(LbL10n l, double m) {
  if (m < 100) return l.wpMeters(m.round());
  if (m < 999.5) return l.wpMeters((m / 10).round() * 10);
  return l.wpKilometers(double.parse((m / 1000).toStringAsFixed(1)));
}

/// Chuỗi lỗi của trường dữ liệu điểm.
String chuLoiDiem(LbL10n l, LoiDiem e) => switch (e) {
  LoiDiem.tenTrong => l.wpErrNameEmpty,
  LoiDiem.tenDai => l.wpErrNameLong(tenToiDa),
  LoiDiem.viDo => l.wpErrLat,
  LoiDiem.kinhDo => l.wpErrLon,
  LoiDiem.caoDo => l.wpErrAlt,
  LoiDiem.ghiChuDai => l.wpErrNoteLong(ghiChuToiDa),
};

/// Chuỗi lỗi của link chia sẻ.
String chuLoiToken(LbL10n l, LoiToken e) => switch (e) {
  LoiToken.hong => l.wpLinkBroken,
  LoiToken.hetHan => l.wpLinkExpired,
  LoiToken.phienBanLa => l.wpLinkNewer,
};

/// Ngày giờ địa phương, định dạng của ngôn ngữ đang dùng.
String ngayGio(BuildContext context, WidgetRef ref, int msUtc) {
  final t = ref.read(gioDiaPhuongProvider)(msUtc);
  final m = MaterialLocalizations.of(context);
  final gio = m.formatTimeOfDay(
    TimeOfDay.fromDateTime(t),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '${m.formatCompactDate(t)} $gio';
}

/// Đọc số người dùng gõ: chấp nhận cả dấu phẩy thập phân (bàn phím vi).
double? docSo(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  return v != null && v.isFinite ? v : null;
}

/// Hiện thông báo ngắn ở đáy màn.
void baoNhanh(BuildContext context, String chu) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(chu)));
}

/// Chữ chọn / chép được (nhấn giữ) với vùng chạm >= 48 dp cho TalkBack (A8b)
/// - `SelectableText` một dòng chỉ cao ~24 dp.
class ChuChonDuoc extends StatelessWidget {
  const new(this.chu, {this.style, this.textAlign, super.key});

  /// Nội dung.
  final String chu;

  /// Kiểu chữ.
  final TextStyle? style;

  /// Căn lề (mặc định đầu dòng).
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
    child: Align(
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : AlignmentDirectional.centerStart,
      child: SelectableText(chu, style: style, textAlign: textAlign),
    ),
  );
}
