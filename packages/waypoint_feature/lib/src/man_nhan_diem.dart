import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:waypoint_feature/src/domain/diem_moc.dart';
import 'package:waypoint_feature/src/domain/token_chia_se.dart';
import 'package:waypoint_feature/src/hien_thi.dart';
import 'package:waypoint_feature/src/icon_diem.dart';
import 'package:waypoint_feature/src/man_dan_duong.dart';
import 'package:waypoint_feature/src/providers.dart';

/// Mở link `compass.tsudev.com/w/<token>` (App Links): xem điểm, lưu vào
/// danh sách, dẫn đường. Nội dung token là dữ liệu KHÔNG tin cậy: chỉ hiển
/// thị dạng chữ, không mở link / không chạy gì từ đó.
class ManNhanDiem extends ConsumerStatefulWidget {
  const new({required this.token, required this.moDanhSach, super.key});

  final String token;

  /// Về tab Điểm (app truyền `context.go('/diem')`).
  final VoidCallback moDanhSach;

  @override
  ConsumerState<ManNhanDiem> createState() => _ManNhanDiemState();
}

class _ManNhanDiemState extends ConsumerState<ManNhanDiem> {
  late final (DiemChiaSe?, LoiToken?) _kq = () {
    try {
      final g = giaiMaToken(
        widget.token,
        bayGio: ref.read(gioDiemProvider)() ~/ 1000,
      );
      return (g, null);
    } on NgoaiLeToken catch (e) {
      return (null, e.loi);
    }
  }();
  var _daLuu = false;

  Future<void> _luu(DiemChiaSe d) async {
    final kho = ref.read(khoDiemProvider);
    if (kho == null || _daLuu) return;
    setState(() => _daLuu = true);
    final gio = ref.read(gioDiemProvider)();
    await kho.luu(
      DiemMoc(
        id: ref.read(taoIdDiemProvider)(),
        ten: d.ten,
        viDo: d.viDo,
        kinhDo: d.kinhDo,
        caoDo: d.caoDo,
        ghiChu: d.ghiChu,
        taoLuc: gio,
        suaLuc: gio,
      ),
    );
    if (!mounted) return;
    baoNhanh(context, context.l10n.wpReceivedSaved);
    widget.moDanhSach();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chu = Theme.of(context).textTheme;
    final phu = Theme.of(context).colorScheme.onSurfaceVariant;
    final (d, loi) = _kq;
    final Widget than;
    if (d == null) {
      than = LbTrangTrong(
        hinh: LbIcon(
          LbIcons.chiaSeQr,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        moTa: chuLoiToken(l, loi!),
        duoi: FilledButton(
          onPressed: widget.moDanhSach,
          child: Text(l.wpGoWaypoints),
        ),
      );
    } else {
      final toaDo = ref.watch(dinhDangToaDoDiemProvider)(d.viDo, d.kinhDo);
      final coKho = ref.watch(khoDiemProvider) != null;
      than = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(LbSpacing.md),
            children: [
              Text(d.ten, style: chu.headlineSmall),
              const SizedBox(height: LbSpacing.md),
              Text(l.wpCoords, style: chu.labelLarge?.copyWith(color: phu)),
              ChuChonDuoc(toaDo, style: chu.bodyLarge),
              if (d.caoDo != null)
                Text(
                  l.wpAltValue(double.parse(d.caoDo!.toStringAsFixed(1))),
                  style: chu.bodyMedium,
                ),
              if (d.ghiChu.isNotEmpty) ...[
                const SizedBox(height: LbSpacing.md),
                Text(l.wpNote, style: chu.labelLarge?.copyWith(color: phu)),
                Text(d.ghiChu, style: chu.bodyLarge),
              ],
              const SizedBox(height: LbSpacing.md),
              Text(
                l.wpReceivedExpires(ngayGio(context, ref, d.hetHan * 1000)),
                style: chu.bodyMedium?.copyWith(color: phu),
              ),
              Text(
                l.wpReceivedUntrusted,
                style: chu.bodySmall?.copyWith(color: phu),
              ),
              const SizedBox(height: LbSpacing.lg),
              Wrap(
                spacing: LbSpacing.sm,
                runSpacing: LbSpacing.sm,
                children: [
                  if (coKho)
                    FilledButton.icon(
                      key: const ValueKey('luu-diem-nhan'),
                      onPressed: _daLuu ? null : () => _luu(d),
                      icon: const LbIcon(LbIcons.diemMoc),
                      label: Text(l.wpReceivedSave),
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('dan-duong-nhan'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ManDanDuong(
                          ten: d.ten,
                          viDo: d.viDo,
                          kinhDo: d.kinhDo,
                        ),
                      ),
                    ),
                    icon: const LbIcon(IconDiem.muiTen),
                    label: Text(l.wpNavigate),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.wpReceivedTitle)),
      body: SafeArea(child: than),
    );
  }
}
