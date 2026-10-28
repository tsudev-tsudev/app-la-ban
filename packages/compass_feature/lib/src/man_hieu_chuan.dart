import 'dart:math' as math;

import 'package:compass_feature/src/bac_thuc_provider.dart';
import 'package:compass_feature/src/domain/tien_do_hieu_chuan.dart';
import 'package:compass_feature/src/huong_provider.dart';
import 'package:compass_feature/src/man_la_ban.dart' show tenMuc;
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:sensors/sensors.dart';

/// Luồng hiệu chuẩn hình số 8: hoạt ảnh hướng dẫn, tiến độ quét hướng / tư
/// thế, xong khi phủ đủ hoặc độ tin cậy cao ổn định.
class ManHieuChuan extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ManHieuChuan> createState() => _ManHieuChuanState();
}

class _ManHieuChuanState extends ConsumerState<ManHieuChuan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoatAnh = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  final _tienDo = TienDoHieuChuan();
  var _daXong = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tôn trọng "Giảm chuyển động" của hệ thống: hình tĩnh.
    if (MediaQuery.disableAnimationsOf(context) || _daXong) {
      _hoatAnh.stop();
    } else if (!_hoatAnh.isAnimating) {
      _hoatAnh.repeat();
    }
  }

  @override
  void dispose() {
    _hoatAnh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tk = LbThemeExt.of(context).colors;
    ref.listen(huongProvider, (_, moi) {
      if (_daXong) return;
      if (moi case AsyncData(:final value)) {
        setState(() => _tienDo.nap(value));
        if (_tienDo.xong) {
          _daXong = true;
          _hoatAnh.stop();
          ref.read(rungProvider)();
        }
      }
    });
    final muc = ref.watch(huongProvider).value?.muc;
    final phanTram = (_tienDo.tiLe * 100).round();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.calibTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, rang) {
            final canh = math.min<double>(
              280,
              math.max<double>(
                120,
                math.min(rang.maxWidth, rang.maxHeight) * 0.5,
              ),
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.all(LbSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: SizedBox(
                          width: canh,
                          height: canh * 0.62,
                          child: AnimatedBuilder(
                            animation: _hoatAnh,
                            builder: (_, _) => CustomPaint(
                              painter: SoTamPainter(
                                t: _hoatAnh.value,
                                duong: tk.outlineStrong,
                                may: _daXong
                                    ? tk.successStrong
                                    : tk.primaryDeep,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: LbSpacing.lg),
                      if (_daXong)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.calibDone(
                              tenMuc(l10n, muc ?? MucTinCay.trungBinh),
                            ),
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        Text(
                          l10n.calibInstruction,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: LbSpacing.md),
                      LinearProgressIndicator(
                        value: _daXong ? 1 : _tienDo.tiLe,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(LbRadius.sm),
                        color: _daXong ? tk.successStrong : tk.primaryDeep,
                        semanticsLabel: l10n.calibTitle,
                      ),
                      const SizedBox(height: LbSpacing.xs),
                      Text(
                        l10n.calibProgress(_daXong ? 100 : phanTram),
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: LbSpacing.lg),
                      Text(
                        l10n.calibTip,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: LbSpacing.lg),
                      FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(l10n.calibFinish),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Hình số 8 nằm ngang (lemniscate Gerono) và "điện thoại" chạy theo nét.
class SoTamPainter extends CustomPainter {
  new({required this.t, required this.duong, required this.may});

  /// Pha hoạt ảnh [0, 1).
  final double t;
  final Color duong;
  final Color may;

  Offset _diem(Size s, double pha) {
    final g = pha * 2 * math.pi;
    return Offset(
      s.width / 2 + math.sin(g) * s.width * 0.42,
      s.height / 2 + math.sin(2 * g) * s.height * 0.38,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final duongVe = Path()..moveTo(_diem(size, 0).dx, _diem(size, 0).dy);
    for (var i = 1; i <= 96; i++) {
      final p = _diem(size, i / 96);
      duongVe.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      duongVe,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, size.height * 0.025)
        ..strokeCap = StrokeCap.round
        ..color = duong,
    );
    // Máy: hình chữ nhật bo góc, xoay theo tiếp tuyến của nét.
    final p = _diem(size, t);
    final q = _diem(size, t + 0.01);
    final goc = math.atan2(q.dy - p.dy, q.dx - p.dx);
    final cao = size.height * 0.34;
    canvas
      ..save()
      ..translate(p.dx, p.dy)
      ..rotate(goc + math.pi / 2)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: cao * 0.52, height: cao),
          Radius.circular(cao * 0.1),
        ),
        Paint()..color = may,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(SoTamPainter old) =>
      old.t != t || old.duong != duong || old.may != may;
}
