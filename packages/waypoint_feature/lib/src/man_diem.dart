import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:sensors/sensors.dart';
import 'package:waypoint_feature/src/domain/diem_moc.dart';
import 'package:waypoint_feature/src/domain/tep_diem.dart';
import 'package:waypoint_feature/src/hien_thi.dart';
import 'package:waypoint_feature/src/icon_diem.dart';
import 'package:waypoint_feature/src/man_chi_tiet_diem.dart';
import 'package:waypoint_feature/src/man_sua_diem.dart';
import 'package:waypoint_feature/src/providers.dart';
import 'package:waypoint_feature/src/thao_tac_tep.dart';

enum _Menu { nhapToaDo, nhapTep, xuatGpx, xuatKml }

/// Tab Điểm: danh sách điểm đã lưu, lưu vị trí hiện tại, nhập / xuất GPX-KML.
/// Không có kho (chế độ an toàn) -> chỉ còn xuất điểm ra GPX.
class ManDiem extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (ref.watch(khoDiemProvider) == null) return const _XuatAnToan();
    final ds = ref.watch(dsDiemProvider).value ?? const <DiemMoc>[];
    // Q60: header mờ khi danh sách cuộn bên dưới (tắt blur ở máy yếu).
    final tatMo = ref.watch(cheDoNheProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LbHeaderMo(
        tatMo: tatMo,
        title: Text(l.tabWaypoints),
        actions: [
          PopupMenuButton<_Menu>(
            key: const ValueKey('menu-diem'),
            tooltip: l.wpMore,
            icon: const LbIcon(IconDiem.tuyChon),
            onSelected: (m) => switch (m) {
              _Menu.nhapToaDo => _moSua(context, dungViTri: false),
              _Menu.nhapTep => chonVaNhapTep(context, ref),
              _Menu.xuatGpx => xuatTep(context, ref, DinhDangTep.gpx, ds),
              _Menu.xuatKml => xuatTep(context, ref, DinhDangTep.kml, ds),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: _Menu.nhapToaDo, child: Text(l.wpAddManual)),
              PopupMenuItem(value: _Menu.nhapTep, child: Text(l.wpImport)),
              PopupMenuItem(
                value: _Menu.xuatGpx,
                enabled: ds.isNotEmpty,
                child: Text(l.wpExportGpx),
              ),
              PopupMenuItem(
                value: _Menu.xuatKml,
                enabled: ds.isNotEmpty,
                child: Text(l.wpExportKml),
              ),
            ],
          ),
        ],
      ),
      // Q60: nút không nền (icon + nhãn), vùng chạm >= 48 dp.
      floatingActionButton: LbNutNoi(
        key: const ValueKey('luu-vi-tri'),
        icon: LbIcons.ghimGps,
        nhan: l.wpSaveHere,
        onPressed: () => _moSua(context, dungViTri: true),
      ),
      body: ds.isEmpty
          ? LbTrangTrong(
              hinh: LbIcon(
                LbIcons.diemMoc,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              tieuDe: l.waypointsEmptyTitle,
              moTa: l.waypointsEmptyBody,
            )
          // MediaQuery TRONG body (Scaffold đã cộng chiều cao header mờ).
          : Builder(
              builder: (context) => ListView.separated(
                // Dưới header mờ ở trên; chừa chỗ cho nút nổi ở cuối.
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top,
                  bottom: 96,
                ),
                itemCount: ds.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _DongDiem(diem: ds[i]),
              ),
            ),
    );
  }

  Future<void> _moSua(BuildContext context, {required bool dungViTri}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ManSuaDiem(dungViTri: dungViTri),
        ),
      );
}

class _DongDiem extends ConsumerWidget {
  const new({required this.diem});

  final DiemMoc diem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toaDo = ref.watch(dinhDangToaDoDiemProvider)(diem.viDo, diem.kinhDo);
    return ListTile(
      key: ValueKey('diem-${diem.id}'),
      leading: LbIcon(
        LbIcons.diemMoc,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(diem.ten),
      subtitle: Text(toaDo),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ManChiTietDiem(id: diem.id)),
      ),
    );
  }
}

/// Chế độ an toàn: CSDL không mở qua Drift -> đọc thô cột v1 rồi xuất GPX
/// (Spec §10.4 "cho phép xuất dữ liệu waypoint").
class _XuatAnToan extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_XuatAnToan> createState() => _XuatAnToanState();
}

class _XuatAnToanState extends ConsumerState<_XuatAnToan> {
  late final Future<List<DiemMoc>?> _ds = _doc();

  Future<List<DiemMoc>?> _doc() async {
    final doc = ref.read(docDiemAnToanProvider);
    if (doc == null) return null;
    try {
      return await doc();
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabWaypoints)),
      body: FutureBuilder(
        future: _ds,
        builder: (context, snap) {
          final xong = snap.connectionState == ConnectionState.done;
          final ds = snap.data;
          return LbTrangTrong(
            hinh: LbIcon(
              IconDiem.tep,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            tieuDe: l.wpSafeTitle,
            moTa: l.wpSafeBody,
            duoi: !xong
                ? const CircularProgressIndicator()
                : ds == null
                ? Text(l.wpSafeReadError, textAlign: TextAlign.center)
                : Column(
                    children: [
                      Text(l.wpSafeCount(ds.length)),
                      const SizedBox(height: LbSpacing.md),
                      FilledButton.icon(
                        key: const ValueKey('xuat-an-toan'),
                        onPressed: ds.isEmpty
                            ? null
                            : () => xuatTep(context, ref, DinhDangTep.gpx, ds),
                        icon: const LbIcon(IconDiem.tep),
                        label: Text(l.wpExportGpx),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// Sao chép [chu] và báo "Đã sao chép".
Future<void> saoChep(BuildContext context, String chu) async {
  await Clipboard.setData(ClipboardData(text: chu));
  if (context.mounted) baoNhanh(context, context.l10n.wpCopied);
}
