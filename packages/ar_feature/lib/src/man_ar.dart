import 'dart:async';

import 'package:ar_feature/src/domain/chieu_ar.dart';
import 'package:ar_feature/src/du_lieu/camera_ar.dart';
import 'package:ar_feature/src/providers.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';

/// Camera AR (A7c): xem trước camera sau, phủ đường chân trời có vạch chia
/// theo phương vị bắc thực và các điểm lưu (tên + khoảng cách). Không ARCore /
/// ARKit: tư thế từ bộ hợp nhất cảm biến, chiếu bằng mô hình lỗ kim.
class ManAr extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ManAr> createState() => _ManArState();
}

class _ManArState extends ConsumerState<ManAr> {
  late final AppLifecycleListener _vongDoi;
  late final CameraAr _camera = ref.read(cameraArProvider);
  XemTruocCamera? _xem;
  LoiCamera? _loi;
  bool _dangMo = false;

  @override
  void initState() {
    super.initState();
    _vongDoi = AppLifecycleListener(
      onPause: () => unawaited(_dong()),
      onResume: () => unawaited(_moLai()),
    );
    // Lớp phủ giả định màn hình dọc (hệ trục cảm biến + camera); máy ảnh hệ
    // thống cũng khoá như vậy.
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    unawaited(_mo());
  }

  /// Quay lại app (sau hộp thoại quyền / Cài đặt / xuống nền): chỉ mở lại
  /// camera khi đã có quyền - KHÔNG tự hỏi lại (đo trên Galaxy M32: hộp thoại
  /// bị hệ thống huỷ trả kết quả rỗng, hỏi lại khi resume thành vòng lặp).
  Future<void> _moLai() async {
    if (_loi == null || await _camera.coQuyen()) await _mo();
  }

  @override
  void dispose() {
    _vongDoi.dispose();
    unawaited(SystemChrome.setPreferredOrientations(const []));
    if (_xem != null) unawaited(_camera.dong());
    super.dispose();
  }

  Future<void> _mo() async {
    if (_dangMo || _xem != null) return;
    _dangMo = true;
    try {
      final x = await _camera.mo();
      if (!mounted) {
        await _camera.dong();
        return;
      }
      setState(() {
        _xem = x;
        _loi = null;
      });
    } on NgoaiLeCamera catch (e) {
      if (mounted) setState(() => _loi = e.loi);
    } finally {
      _dangMo = false;
    }
  }

  Future<void> _dong() async {
    if (_xem == null) return;
    setState(() => _xem = null);
    await _camera.dong();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final xem = _xem;
    final loi = _loi;
    return Theme(
      // Khung camera luôn tối: chữ / icon sáng dễ đọc trên ảnh thật.
      data: LbTheme.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black54,
          title: Text(l10n.arTitle),
        ),
        body: loi != null
            ? SafeArea(
                child: _BaoLoi(loi: loi, thuLai: _mo),
              )
            : _LopAr(xem: xem),
      ),
    );
  }
}

class _BaoLoi extends ConsumerWidget {
  const new({required this.loi, required this.thuLai});

  final LoiCamera loi;
  final Future<void> Function() thuLai;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return LbTrangTrong(
      hinh: const LbIcon(LbIcons.cameraAr, size: 96),
      moTa: switch (loi) {
        LoiCamera.tuChoi => l10n.arPermission,
        LoiCamera.tuChoiHan => l10n.arPermissionBlocked,
        LoiCamera.khongCo => l10n.arNoCamera,
      },
      duoi: switch (loi) {
        LoiCamera.tuChoi => FilledButton(
          onPressed: thuLai,
          child: Text(l10n.arGrant),
        ),
        LoiCamera.tuChoiHan => FilledButton(
          onPressed: () => ref.read(cameraArProvider).moCaiDat(),
          child: Text(l10n.arOpenSettings),
        ),
        LoiCamera.khongCo => OutlinedButton(
          onPressed: thuLai,
          child: Text(l10n.arRetry),
        ),
      },
    );
  }
}

/// Ảnh camera phủ kín + lớp phủ hướng / điểm.
class _LopAr extends ConsumerWidget {
  const new({required this.xem});

  final XemTruocCamera? xem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final doc = ref.watch(docArProvider);
    final diem = ref.watch(diemArProvider);
    final coViTri = ref.watch(coViTriArProvider);
    final x = xem;
    return LayoutBuilder(
      builder: (context, rang) {
        final rong = rang.maxWidth;
        final cao = rang.maxHeight;
        // Chưa mở được camera: trường nhìn điển hình máy điện thoại dọc.
        final truongNhin = x == null
            ? (ngang: 49.0, doc: 63.0)
            : truongNhinPhuKin(x.truongNhin, x.rong / x.cao, rong, cao);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (x != null) _AnhCamera(xem: x),
            if (doc != null)
              _PhuHuong(
                doc: doc,
                diem: diem,
                truongNhin: truongNhin,
                rong: rong,
                cao: cao,
              )
            else
              Center(
                child: Text(
                  l10n.compassStarting,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            PositionedDirectional(
              start: LbSpacing.md,
              end: LbSpacing.md,
              bottom: LbSpacing.md,
              child: SafeArea(
                child: _ChanDuoi(doc: doc, coViTri: coViTri),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnhCamera extends StatelessWidget {
  const new({required this.xem});

  final XemTruocCamera xem;

  @override
  Widget build(BuildContext context) {
    // Texture chưa xoay -> kích thước gốc là cảm biến nằm ngang, xoay về dọc.
    final le = xem.xoay.isOdd;
    final texture = SizedBox(
      width: le ? xem.cao : xem.rong,
      height: le ? xem.rong : xem.cao,
      child: Texture(textureId: xem.texture),
    );
    return ExcludeSemantics(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: xem.rong,
            height: xem.cao,
            child: xem.xoay == 0
                ? texture
                : RotatedBox(quarterTurns: xem.xoay, child: texture),
          ),
        ),
      ),
    );
  }
}

const Color _mauChu = Colors.white;
const List<Shadow> _bong = [Shadow(blurRadius: 3), Shadow(blurRadius: 6)];

class _PhuHuong extends StatelessWidget {
  const new({
    required this.doc,
    required this.diem,
    required this.truongNhin,
    required this.rong,
    required this.cao,
  });

  final DocAr doc;
  final List<DiemAr> diem;
  final TruongNhin truongNhin;
  final double rong;
  final double cao;

  DiemManHinh? _chieu(double phuongVi, [double ngoc = 0]) => chieuLenKhung(
    phuongVi: phuongVi,
    ngoc: ngoc,
    camera: doc.camera,
    truongNhin: truongNhin,
    rong: rong,
    cao: cao,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chu = Theme.of(context).textTheme;
    final nhan = <Widget>[];
    for (final g in vachChanTroi(doc.camera.phuongVi, truongNhin.ngang / 2)) {
      final d = _chieu(g);
      if (d == null) continue;
      if (g % 45 != 0) {
        // Vạch phụ: số độ nhỏ dưới đường chân trời.
        nhan.add(
          Positioned(
            left: d.x - 24,
            top: d.y + LbSpacing.xs,
            width: 48,
            child: ExcludeSemantics(
              child: Text(
                '${g.round()}',
                textAlign: TextAlign.center,
                style: chu.labelSmall?.copyWith(color: _mauChu, shadows: _bong),
              ),
            ),
          ),
        );
        continue;
      }
      final chinh = g % 90 == 0;
      nhan.add(
        Positioned(
          left: d.x - 40,
          top: d.y - (chinh ? 44 : 36),
          width: 80,
          child: ExcludeSemantics(
            child: Text(
              _tenHuong(l10n, g),
              textAlign: TextAlign.center,
              style: (chinh ? chu.titleLarge : chu.titleSmall)?.copyWith(
                color: g == 0 ? LbColors.dark.accent : _mauChu,
                fontWeight: FontWeight.w700,
                shadows: _bong,
              ),
            ),
          ),
        ),
      );
    }
    final nuaNgang = truongNhin.ngang / 2;
    for (final p in diem) {
      final lech = gocLechAr(doc.camera.phuongVi, p.phuongVi);
      final kc = _khoangCach(l10n, p.khoangCachM);
      final d = lech.abs() < nuaNgang ? _chieu(p.phuongVi, p.ngoc) : null;
      if (d != null && d.y > 0 && d.y < cao) {
        nhan.add(
          Positioned(
            left: d.x - 70,
            top: d.y - 76,
            width: 140,
            child: _NhanDiem(ten: p.ten, khoangCach: kc),
          ),
        );
      } else {
        // Ngoài khung: mũi tên ở mép, chỉ phía cần quay.
        final phai = lech > 0;
        nhan.add(
          PositionedDirectional(
            top: cao * 0.32 + 52.0 * diem.indexOf(p).clamp(0, 4),
            start: phai ? null : LbSpacing.xs,
            end: phai ? LbSpacing.xs : null,
            child: _MuiTenDiem(ten: p.ten, khoangCach: kc, phai: phai),
          ),
        );
      }
    }
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: CustomPaint(
              painter: _VeChanTroi(
                cacVach:
                    [
                      for (final g in vachChanTroi(
                        doc.camera.phuongVi,
                        nuaNgang,
                      ))
                        if (_chieu(g) case final d?) (g: g, d: d),
                    ]..sort(
                      (a, b) => gocLechAr(
                        doc.camera.phuongVi,
                        a.g,
                      ).compareTo(gocLechAr(doc.camera.phuongVi, b.g)),
                    ),
                diemDiem: [
                  for (final p in diem)
                    if (gocLechAr(doc.camera.phuongVi, p.phuongVi).abs() <
                        nuaNgang)
                      ?_chieu(p.phuongVi, p.ngoc),
                ],
                mauDiem: LbColors.dark.secondary,
              ),
            ),
          ),
        ),
        ...nhan,
      ],
    );
  }
}

String _tenHuong(LbL10n l, double g) => switch (g.round()) {
  0 => l.dirShortN,
  45 => l.dirShortNE,
  90 => l.dirShortE,
  135 => l.dirShortSE,
  180 => l.dirShortS,
  225 => l.dirShortSW,
  270 => l.dirShortW,
  _ => l.dirShortNW,
};

String _khoangCach(LbL10n l, double m) {
  final k = khoangCachGon(m);
  return k.km ? l.arDistanceKm(k.giaTri) : l.arDistanceM(k.giaTri.round());
}

class _VeChanTroi extends CustomPainter {
  new({required this.cacVach, required this.diemDiem, required this.mauDiem});

  final List<({double g, DiemManHinh d})> cacVach;
  final List<DiemManHinh> diemDiem;
  final Color mauDiem;

  @override
  void paint(Canvas canvas, Size size) {
    final bong = Paint()
      ..color = Colors.black45
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final net = Paint()
      ..color = _mauChu
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (cacVach.length >= 2) {
      // Nối các vạch theo thứ tự trái -> phải (đã sắp theo góc lệch).
      final duong = Path()..moveTo(cacVach.first.d.x, cacVach.first.d.y);
      for (final v in cacVach.skip(1)) {
        duong.lineTo(v.d.x, v.d.y);
      }
      for (final p in [bong, net]) {
        canvas.drawPath(duong, Paint.from(p)..style = PaintingStyle.stroke);
      }
    }
    for (final v in cacVach) {
      final dai = v.g % 90 == 0 ? 18.0 : (v.g % 45 == 0 ? 12.0 : 7.0);
      final a = Offset(v.d.x, v.d.y - dai);
      final b = Offset(v.d.x, v.d.y);
      for (final p in [bong, net]) {
        canvas.drawLine(a, b, p);
      }
    }
    for (final d in diemDiem) {
      final c = Offset(d.x, d.y);
      canvas
        ..drawCircle(c, 10, Paint()..color = Colors.white)
        ..drawCircle(c, 7, Paint()..color = mauDiem);
    }
    // Tâm ngắm: hướng camera đang chỉ.
    final tam = Offset(size.width / 2, size.height / 2);
    for (final p in [bong, net]) {
      canvas
        ..drawLine(tam - const Offset(0, 14), tam + const Offset(0, 14), p)
        ..drawLine(tam - const Offset(14, 0), tam + const Offset(14, 0), p);
    }
  }

  @override
  bool shouldRepaint(_VeChanTroi cu) =>
      cu.cacVach != cacVach || cu.diemDiem != diemDiem;
}

class _NhanDiem extends StatelessWidget {
  const new({required this.ten, required this.khoangCach});

  final String ten;
  final String khoangCach;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$ten, $khoangCach',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(LbRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LbSpacing.xs,
              vertical: LbSpacing.xxs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: chu.labelLarge?.copyWith(color: _mauChu),
                ),
                Text(
                  khoangCach,
                  maxLines: 1,
                  style: chu.labelMedium?.copyWith(color: _mauChu),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MuiTenDiem extends StatelessWidget {
  const new({required this.ten, required this.khoangCach, required this.phai});

  final String ten;
  final String khoangCach;
  final bool phai;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final muiTen = Padding(
      padding: const EdgeInsets.symmetric(horizontal: LbSpacing.xxs),
      child: CustomPaint(
        size: const Size(8, 12),
        painter: _VeMuiTen(phai: phai),
      ),
    );
    return Semantics(
      container: true,
      label: '$ten, $khoangCach',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(LbRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(LbSpacing.xxs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!phai) muiTen,
                  Flexible(
                    child: Text(
                      '$ten · $khoangCach',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: chu.labelMedium?.copyWith(color: _mauChu),
                    ),
                  ),
                  if (phai) muiTen,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChanDuoi extends StatelessWidget {
  const new({required this.doc, required this.coViTri});

  final DocAr? doc;
  final bool coViTri;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chu = Theme.of(context).textTheme;
    final d = doc;
    final nhac = [
      if (d != null && !d.dungDung) l10n.arHoldUpright,
      if (d != null && d.canHieuChuan) l10n.arCalibrate,
      if (!coViTri) l10n.arNoLocation,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final n in nhac)
          Padding(
            padding: const EdgeInsets.only(bottom: LbSpacing.xs),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(LbRadius.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LbSpacing.sm,
                  vertical: LbSpacing.xs,
                ),
                child: Text(
                  n,
                  textAlign: TextAlign.center,
                  style: chu.bodyMedium?.copyWith(color: _mauChu),
                ),
              ),
            ),
          ),
        if (d != null)
          Semantics(
            liveRegion: false,
            label: l10n.arHeadingLabel(d.camera.phuongVi.round() % 360),
            child: ExcludeSemantics(
              child: Text(
                '${d.camera.phuongVi.round() % 360}°',
                style: chu.displaySmall?.copyWith(
                  color: _mauChu,
                  fontWeight: FontWeight.w700,
                  shadows: _bong,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tam giác nhỏ chỉ phía cần quay máy.
class _VeMuiTen extends CustomPainter {
  const new({required this.phai});

  final bool phai;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (phai) {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height);
    } else {
      p
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height);
    }
    canvas.drawPath(p..close(), Paint()..color = _mauChu);
  }

  @override
  bool shouldRepaint(_VeMuiTen cu) => cu.phai != phai;
}
