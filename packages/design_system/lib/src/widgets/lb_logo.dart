import 'package:design_system/src/domain/kim_tat_dan.dart';
import 'package:design_system/src/tokens/tokens.g.dart';
import 'package:flutter/widgets.dart';

// Màu riêng của logo (phương án B) - đồng bộ với MAU trong
// tools/build/logo-hinh.mjs; các màu còn lại lấy từ token.
const _cyanToi = Color(0xFF00B8D4);
const _vienTam = Color(0xFF0B1220);

/// Biểu tượng logo La bàn (vòng + kim kim cương) vẽ bằng CustomPainter,
/// cùng hình học với design/logo/bieu-tuong.svg (hộp 512, tâm 256).
class LbLogo extends StatelessWidget {
  const new({super.key, this.size = 96, this.gocKim = 0, this.semanticLabel});

  /// Cạnh hộp vuông (dp).
  final double size;

  /// Góc lệch của kim so với hướng Bắc (radian, chiều kim đồng hồ).
  final double gocKim;

  /// Nhãn cho trình đọc màn hình (truyền chuỗi đã dịch; null = trang trí).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ve = CustomPaint(
      size: Size.square(size),
      painter: LbLogoPainter(gocKim: gocKim),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: ve);
    return Semantics(label: semanticLabel, image: true, child: ve);
  }
}

/// Painter của [LbLogo].
class LbLogoPainter extends CustomPainter {
  const new({this.gocKim = 0});

  final double gocKim;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 512, size.height / 512);
    const tam = Offset(256, 256);

    final vong = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 44
      ..shader = LinearGradient(
        colors: [LbColors.light.secondary, LbColors.light.primaryDeep],
      ).createShader(const Rect.fromLTWH(56, 56, 400, 400));
    canvas.drawCircle(tam, 200, vong);

    final cham = Paint()..color = LbColors.dark.primaryDeep;
    canvas
      ..drawCircle(const Offset(110, 256), 11, cham)
      ..drawCircle(const Offset(402, 256), 11, cham)
      ..translate(tam.dx, tam.dy)
      ..rotate(gocKim)
      ..translate(-tam.dx, -tam.dy);

    void tamGiac(Offset a, Offset b, Color mau) {
      final p = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(tam.dx, tam.dy)
        ..lineTo(b.dx, b.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = mau);
    }

    const bac = Offset(256, 84);
    const nam = Offset(256, 428);
    const dong = Offset(306, 256);
    const tay = Offset(206, 256);
    tamGiac(bac, dong, _cyanToi);
    tamGiac(bac, tay, LbColors.light.primary);
    tamGiac(nam, dong, LbColors.light.accent);
    tamGiac(nam, tay, LbColors.dark.accent);

    canvas
      ..drawCircle(tam, 18, Paint()..color = const Color(0xFFFFFFFF))
      ..drawCircle(
        tam,
        18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = _vienTam,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(LbLogoPainter oldDelegate) => oldDelegate.gocKim != gocKim;
}

/// Logo có hoạt ảnh: kim dao động tắt dần rồi chỉ Bắc (splash / onboarding).
/// Tôn trọng "giảm chuyển động" của hệ thống: khi bật thì vẽ tĩnh và gọi
/// [onXong] ngay sau khung hình đầu.
class LbLogoDong extends StatefulWidget {
  const new({super.key, this.size = 160, this.semanticLabel, this.onXong});

  final double size;
  final String? semanticLabel;
  final VoidCallback? onXong;

  @override
  State<LbLogoDong> createState() => _LbLogoDongState();
}

class _LbLogoDongState extends State<LbLogoDong>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: LbMotion.splash * 2,
  )..addStatusListener(_trangThai);
  bool _daBao = false;

  void _trangThai(AnimationStatus s) {
    if (s == AnimationStatus.completed) _bao();
  }

  void _bao() {
    if (_daBao) return;
    _daBao = true;
    widget.onXong?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ac.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _bao());
    } else if (!_ac.isAnimating && !_ac.isCompleted) {
      _ac.forward();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, _) {
        final giay = _ac.value * _ac.duration!.inMilliseconds / 1000;
        final goc = _ac.isCompleted ? 0.0 : gocKimTatDan(giay);
        return LbLogo(
          size: widget.size,
          gocKim: goc,
          semanticLabel: widget.semanticLabel,
        );
      },
    );
  }
}
