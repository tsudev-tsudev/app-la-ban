import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:waypoint_feature/src/domain/diem_moc.dart';
import 'package:waypoint_feature/src/domain/ma_qr.dart';
import 'package:waypoint_feature/src/domain/token_chia_se.dart';
import 'package:waypoint_feature/src/hien_thi.dart';
import 'package:waypoint_feature/src/icon_diem.dart';
import 'package:waypoint_feature/src/man_diem.dart';
import 'package:waypoint_feature/src/providers.dart';

/// Hạn link cho người dùng chọn (ngày).
const hanLinkNgay = [1, 7, 30];

/// Chia sẻ một điểm: link tự chứa có hạn + mã QR.
class ManChiaSe extends ConsumerStatefulWidget {
  const new({required this.diem, super.key});

  final DiemMoc diem;

  @override
  ConsumerState<ManChiaSe> createState() => _ManChiaSeState();
}

class _ManChiaSeState extends ConsumerState<ManChiaSe> {
  var _ngay = 7;

  /// Mốc tính hạn: lúc mở màn (link không đổi theo từng lần vẽ lại).
  late final int _giay = ref.read(gioDiemProvider)() ~/ 1000;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chu = Theme.of(context).textTheme;
    final Widget than;
    if (!ref.watch(choPhepChiaSeProvider)) {
      than = Text(l.wpShareDisabled, style: chu.bodyLarge);
    } else {
      final link = linkChiaSe(widget.diem, hetHan: _giay + _ngay * 86400);
      than = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.wpShareExpiry, style: chu.titleSmall),
          const SizedBox(height: LbSpacing.xs),
          SegmentedButton<int>(
            segments: [
              for (final n in hanLinkNgay)
                ButtonSegment(value: n, label: Text(l.wpDays(n))),
            ],
            selected: {_ngay},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _ngay = s.first),
          ),
          const SizedBox(height: LbSpacing.lg),
          Center(
            child: Semantics(
              label: l.wpQrSemantics,
              image: true,
              child: VeQr(ma: maHoaQr(link), canh: 240),
            ),
          ),
          const SizedBox(height: LbSpacing.md),
          ChuChonDuoc(
            link,
            key: const ValueKey('link-chia-se'),
            style: chu.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LbSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: LbSpacing.sm,
            runSpacing: LbSpacing.sm,
            children: [
              FilledButton.icon(
                key: const ValueKey('gui-link'),
                onPressed: () => ref
                    .read(nenTangDiemProvider)
                    .chiaSeChu(link, tieuDe: l.wpShareTitle),
                icon: const LbIcon(LbIcons.chiaSeQr),
                label: Text(l.wpSendLink),
              ),
              OutlinedButton.icon(
                key: const ValueKey('sao-chep-link'),
                onPressed: () => saoChep(context, link),
                icon: const LbIcon(IconDiem.saoChep),
                label: Text(l.wpCopyLink),
              ),
            ],
          ),
          const SizedBox(height: LbSpacing.md),
          Text(
            l.wpShareInfo(ghiChuChiaSeToiDa),
            style: chu.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.wpShareTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(LbSpacing.md),
              children: [
                Text(widget.diem.ten, style: chu.titleLarge),
                const SizedBox(height: LbSpacing.md),
                than,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vẽ mã QR: ô tối đen trên nền trắng + lề 4 ô (chuẩn ISO), giữ nguyên ở
/// theme tối để máy quét đọc được. Co lại theo chỗ trống, tối đa [canh].
class VeQr extends StatelessWidget {
  const new({required this.ma, required this.canh, super.key});

  final MaQr ma;
  final double canh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, rang) {
      final c = rang.maxWidth.isFinite && rang.maxWidth < canh
          ? rang.maxWidth
          : canh;
      return CustomPaint(size: Size.square(c), painter: _ButQr(ma));
    },
  );
}

class _ButQr extends CustomPainter {
  new(this.ma);

  final MaQr ma;

  @override
  void paint(Canvas canvas, Size size) {
    final o = size.width / (ma.canh + 8);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final p = Path();
    for (var y = 0; y < ma.canh; y++) {
      for (var x = 0; x < ma.canh; x++) {
        if (ma.toi(x, y)) {
          p.addRect(Rect.fromLTWH((x + 4) * o, (y + 4) * o, o, o));
        }
      }
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = Colors.black
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_ButQr cu) => cu.ma != ma;
}
