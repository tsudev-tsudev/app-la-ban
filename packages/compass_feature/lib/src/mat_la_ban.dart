import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:compass_feature/src/domain/noi_suy_goc.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Màu của mặt la bàn (lấy từ token theo sáng / tối).
@immutable
final class MauMatLaBan {
  const new({
    required this.nen,
    required this.vien,
    required this.vachNho,
    required this.vachLon,
    required this.chu,
    required this.chuPhu,
    required this.bac,
    required this.moc,
  });

  factory tuTheme(BuildContext context) {
    final tk = LbThemeExt.of(context).colors;
    return MauMatLaBan(
      nen: tk.surfaceRaised,
      vien: tk.outline,
      vachNho: tk.outlineStrong,
      vachLon: tk.text,
      chu: tk.text,
      chuPhu: tk.textMuted,
      bac: tk.accentStrong,
      moc: tk.primaryDeep,
    );
  }

  final Color nen;
  final Color vien;
  final Color vachNho;
  final Color vachLon;
  final Color chu;
  final Color chuPhu;

  /// Vạch / chữ Bắc trên mặt số.
  final Color bac;

  /// Vạch mốc cố định (lubber line) chỉ hướng mép trên máy.
  final Color moc;

  @override
  bool operator ==(Object other) =>
      other is MauMatLaBan &&
      other.nen == nen &&
      other.vien == vien &&
      other.vachNho == vachNho &&
      other.vachLon == vachLon &&
      other.chu == chu &&
      other.chuPhu == chuPhu &&
      other.bac == bac &&
      other.moc == moc;

  @override
  int get hashCode =>
      Object.hash(nen, vien, vachNho, vachLon, chu, chuPhu, bac, moc);
}

/// Mặt la bàn: mặt số xoay theo [phuongVi] (chữ Bắc luôn chỉ bắc đang chọn),
/// vạch mốc cố định ở đỉnh.
///
/// Mặt số raster MỘT lần thành ảnh (chỉ làm lại khi đổi màu / ngôn ngữ / cỡ /
/// mật độ điểm ảnh); mỗi khung hình chỉ vẽ ảnh đó với phép xoay mới. Impeller
/// không có raster cache nên [RepaintBoundary] không đủ: đo trên Galaxy M32
/// (Impeller GLES) vẽ lại 180 vạch + chữ mỗi khung tốn ~12,8 ms raster, quá
/// ngân sách 11,1 ms của màn 90 Hz.
///
/// Góc xoay nội suy theo từng vsync ([BoNoiSuyGoc]) và chỉ dựng lại phép
/// xoay, không dựng lại cả màn hình mỗi khung.
class MatLaBan extends StatefulWidget {
  const new({
    required this.phuongVi,
    required this.canh,
    required this.nhan8,
    required this.mau,
    super.key,
  });

  final double phuongVi;
  final double canh;

  /// Ký hiệu 8 hướng theo chiều kim đồng hồ từ Bắc (đã dịch).
  final List<String> nhan8;
  final MauMatLaBan mau;

  @override
  State<MatLaBan> createState() => _MatLaBanState();
}

class _MatLaBanState extends State<MatLaBan>
    with SingleTickerProviderStateMixin {
  final _noiSuy = BoNoiSuyGoc();
  late final ValueNotifier<double> _goc;
  late final Ticker _nhip = createTicker(_moiKhung);
  ui.Image? _anh;
  MatSoPainter? _veAnh;
  double _canhAnh = 0;
  double _tiLeAnh = 0;

  ui.Image _anhMatSo(double tiLe, TextDirection dir) {
    final ve = MatSoPainter(
      nhan8: widget.nhan8,
      mau: widget.mau,
      huongChu: dir,
    );
    final cu = _anh;
    final veCu = _veAnh;
    if (cu != null &&
        veCu != null &&
        _canhAnh == widget.canh &&
        _tiLeAnh == tiLe &&
        !ve.shouldRepaint(veCu)) {
      return cu;
    }
    final px = math.max(1, (widget.canh * tiLe).ceil());
    final ghi = ui.PictureRecorder();
    final canvas = Canvas(ghi)..scale(px / widget.canh);
    ve.paint(canvas, Size.square(widget.canh));
    final hinh = ghi.endRecording();
    final anh = hinh.toImageSync(px, px);
    hinh.dispose();
    cu?.dispose();
    _anh = anh;
    _veAnh = ve;
    _canhAnh = widget.canh;
    _tiLeAnh = tiLe;
    return anh;
  }

  static int get _bayGioUs =>
      SchedulerBinding.instance.currentFrameTimeStamp.inMicroseconds;

  @override
  void initState() {
    super.initState();
    _noiSuy.dat(widget.phuongVi, 0);
    _goc = ValueNotifier(_noiSuy.giaTri(0));
  }

  @override
  void didUpdateWidget(MatLaBan old) {
    super.didUpdateWidget(old);
    if (widget.phuongVi == old.phuongVi) return;
    _noiSuy.dat(widget.phuongVi, _bayGioUs);
    if (!_nhip.isActive) _nhip.start();
  }

  void _moiKhung(Duration _) {
    final t = _bayGioUs;
    _goc.value = _noiSuy.giaTri(t);
    if (_noiSuy.xong(t)) _nhip.stop();
  }

  @override
  void dispose() {
    _nhip.dispose();
    _goc.dispose();
    _anh?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anh = _anhMatSo(
      MediaQuery.devicePixelRatioOf(context),
      Directionality.of(context),
    );
    return SizedBox.square(
      dimension: widget.canh,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder(
            valueListenable: _goc,
            builder: (context, goc, child) =>
                Transform.rotate(angle: -goc * math.pi / 180, child: child),
            child: RawImage(
              image: anh,
              width: widget.canh,
              height: widget.canh,
            ),
          ),
          CustomPaint(painter: VachMocPainter(widget.mau.moc)),
        ],
      ),
    );
  }
}

/// Mặt số: nền, vạch mỗi 2° / 10° / 30°, số độ mỗi 30°, chữ 8 hướng.
class MatSoPainter extends CustomPainter {
  new({required this.nhan8, required this.mau, required this.huongChu});

  final List<String> nhan8;
  final MauMatLaBan mau;
  final TextDirection huongChu;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final tam = size.center(Offset.zero);
    canvas
      ..drawCircle(tam, r, Paint()..color = mau.nen)
      ..drawCircle(
        tam,
        r - r * 0.01,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.02
          ..color = mau.vien,
      );

    final nho = Paint()
      ..color = mau.vachNho
      ..strokeWidth = math.max(1, r * 0.008)
      ..strokeCap = StrokeCap.round;
    final lon = Paint()
      ..color = mau.vachLon
      ..strokeWidth = math.max(1.5, r * 0.016)
      ..strokeCap = StrokeCap.round;
    final bac = Paint()
      ..color = mau.bac
      ..strokeWidth = math.max(2, r * 0.024)
      ..strokeCap = StrokeCap.round;
    final rNgoai = r * 0.93;
    for (var d = 0; d < 360; d += 2) {
      final dai = d % 30 == 0
          ? r * 0.1
          : d % 10 == 0
          ? r * 0.065
          : r * 0.035;
      final but = d == 0 ? bac : (d % 10 == 0 ? lon : nho);
      final g = (d - 90) * math.pi / 180;
      final huong = Offset(math.cos(g), math.sin(g));
      canvas.drawLine(tam + huong * rNgoai, tam + huong * (rNgoai - dai), but);
    }

    // Số độ mỗi 30° (trừ 4 hướng chính đã có chữ), quay theo vòng tròn.
    for (var d = 30; d < 360; d += 30) {
      if (d % 90 == 0) continue;
      _chuXoay(
        canvas,
        tam,
        '$d',
        d.toDouble(),
        r * 0.74,
        r * 0.2,
        TextStyle(
          fontFamily: LbType.fontFamily,
          package: LbType.fontPackage,
          fontSize: r * 0.075,
          fontWeight: FontWeight.w600,
          color: mau.chuPhu,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    // Chữ 8 hướng: hướng chính lớn (Bắc màu nhấn), hướng phụ nhỏ hơn.
    for (var i = 0; i < 8; i++) {
      final chinh = i.isEven;
      _chuXoay(
        canvas,
        tam,
        nhan8[i],
        i * 45.0,
        chinh ? r * 0.58 : r * 0.6,
        chinh ? r * 0.34 : r * 0.24,
        TextStyle(
          fontFamily: LbType.fontFamily,
          package: LbType.fontPackage,
          fontSize: chinh ? r * (i == 0 ? 0.18 : 0.14) : r * 0.08,
          fontWeight: chinh ? FontWeight.w800 : FontWeight.w600,
          color: i == 0 ? mau.bac : (chinh ? mau.chu : mau.chuPhu),
          height: 1,
        ),
      );
    }

    // Tâm: vòng nhỏ + chữ thập mảnh.
    final tamBut = Paint()
      ..color = mau.vachNho
      ..strokeWidth = math.max(1, r * 0.006);
    canvas
      ..drawLine(tam - Offset(r * 0.12, 0), tam + Offset(r * 0.12, 0), tamBut)
      ..drawLine(tam - Offset(0, r * 0.12), tam + Offset(0, r * 0.12), tamBut)
      ..drawCircle(
        tam,
        r * 0.035,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, r * 0.01)
          ..color = mau.vachLon,
      );
  }

  /// Chữ đặt ở góc [doGoc] trên vòng bán kính [banKinh], chân chữ hướng tâm;
  /// rộng hơn [rongToiDa] (bản dịch dài) thì thu nhỏ cho vừa.
  void _chuXoay(
    Canvas canvas,
    Offset tam,
    String chu,
    double doGoc,
    double banKinh,
    double rongToiDa,
    TextStyle kieu,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: chu, style: kieu),
      textDirection: huongChu,
      textScaler: TextScaler.noScaling,
    )..layout();
    canvas
      ..save()
      ..translate(tam.dx, tam.dy)
      ..rotate(doGoc * math.pi / 180)
      ..translate(0, -banKinh);
    if (tp.width > rongToiDa) {
      final k = rongToiDa / tp.width;
      canvas.scale(k, k);
    }
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
    tp.dispose();
  }

  @override
  bool shouldRepaint(MatSoPainter old) =>
      old.mau != mau ||
      old.huongChu != huongChu ||
      !_cungDanhSach(old.nhan8, nhan8);

  static bool _cungDanhSach(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Vạch mốc cố định: tam giác ở đỉnh chỉ vào mặt số.
class VachMocPainter extends CustomPainter {
  new(this.mau);

  final Color mau;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final cx = size.width / 2;
    final dinh = size.height / 2 - r;
    final rong = r * 0.07;
    canvas.drawPath(
      Path()
        ..moveTo(cx - rong, dinh - r * 0.005)
        ..lineTo(cx + rong, dinh - r * 0.005)
        ..lineTo(cx, dinh + r * 0.13)
        ..close(),
      Paint()..color = mau,
    );
  }

  @override
  bool shouldRepaint(VachMocPainter old) => old.mau != mau;
}
