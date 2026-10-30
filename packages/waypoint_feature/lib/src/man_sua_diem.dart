import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:waypoint_feature/src/domain/diem_moc.dart';
import 'package:waypoint_feature/src/du_lieu/kho_diem.dart';
import 'package:waypoint_feature/src/hien_thi.dart';
import 'package:waypoint_feature/src/icon_diem.dart';
import 'package:waypoint_feature/src/nghe_anh_diem.dart';
import 'package:waypoint_feature/src/providers.dart';
import 'package:waypoint_feature/src/the_vi_tri_diem.dart';

/// Tạo điểm mới ([diem] null) hoặc sửa điểm. [dungViTri]: điền toạ độ từ
/// lần đọc GPS đầu tiên (nút "Lưu vị trí").
class ManSuaDiem extends ConsumerStatefulWidget {
  const new({this.diem, this.dungViTri = false, super.key});

  final DiemMoc? diem;
  final bool dungViTri;

  @override
  ConsumerState<ManSuaDiem> createState() => _ManSuaDiemState();
}

class _ManSuaDiemState extends ConsumerState<ManSuaDiem> {
  late final _ten = TextEditingController(text: widget.diem?.ten);
  late final _viDo = TextEditingController(text: _so(widget.diem?.viDo));
  late final _kinhDo = TextEditingController(text: _so(widget.diem?.kinhDo));
  late final _caoDo = TextEditingController(text: _so(widget.diem?.caoDo));
  late final _ghiChu = TextEditingController(text: widget.diem?.ghiChu);

  /// Ảnh mới chưa lưu + id ảnh cũ sẽ xoá khi bấm Lưu.
  final _anhMoi = <AnhMoi>[];
  final _xoaAnh = <int>{};
  Set<LoiDiem> _loi = const {};
  late bool _choViTri = widget.dungViTri && widget.diem == null;
  var _dangLuu = false;
  var _daGoiYTen = false;

  static String _so(double? v) => v == null ? '' : v.toString();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Điểm mới: tên gợi ý "Điểm N" (đổi được).
    if (widget.diem == null && !_daGoiYTen) {
      _daGoiYTen = true;
      final n = ref.read(dsDiemProvider).value?.length ?? 0;
      _ten.text = context.l10n.wpUnnamed(n + 1);
    }
  }

  @override
  void dispose() {
    for (final c in [_ten, _viDo, _kinhDo, _caoDo, _ghiChu]) {
      c.dispose();
    }
    super.dispose();
  }

  void _dienViTri(ViTriHienTai v) {
    setState(() {
      _viDo.text = v.viDo.toStringAsFixed(7);
      _kinhDo.text = v.kinhDo.toStringAsFixed(7);
      if (v.caoDo != null) _caoDo.text = v.caoDo!.toStringAsFixed(1);
      _choViTri = false;
    });
  }

  Future<void> _themAnh() async {
    final l = context.l10n;
    try {
      final a = await ref.read(nenTangDiemProvider).chonAnh();
      if (a != null && mounted) setState(() => _anhMoi.add(a));
    } on PlatformException {
      if (mounted) baoNhanh(context, l.wpPhotoError);
    }
  }

  Future<void> _luu() async {
    final kho = ref.read(khoDiemProvider);
    if (kho == null || _dangLuu) return;
    final viDo = docSo(_viDo.text);
    final kinhDo = docSo(_kinhDo.text);
    final caoTho = _caoDo.text.trim();
    final caoDo = docSo(caoTho);
    final loi = {
      ...kiemDiem(
        ten: _ten.text,
        viDo: viDo,
        kinhDo: kinhDo,
        caoDo: caoDo,
        ghiChu: _ghiChu.text,
      ),
      if (caoTho.isNotEmpty && caoDo == null) LoiDiem.caoDo,
    };
    setState(() => _loi = loi);
    if (loi.isNotEmpty) return;
    setState(() => _dangLuu = true);
    final gio = ref.read(gioDiemProvider)();
    final cu = widget.diem;
    final d = DiemMoc(
      id: cu?.id ?? ref.read(taoIdDiemProvider)(),
      ten: _ten.text.trim(),
      viDo: viDo!,
      kinhDo: kinhDo!,
      caoDo: caoDo,
      ghiChu: _ghiChu.text.trim(),
      taoLuc: cu?.taoLuc ?? gio,
      suaLuc: gio,
    );
    await kho.luu(d);
    for (final id in _xoaAnh) {
      await kho.xoaAnh(id);
    }
    for (final a in _anhMoi) {
      await kho.themAnh(d.id, a, luc: gio);
    }
    if (mounted) Navigator.of(context).pop(d.id);
  }

  String? _loiCua(Set<LoiDiem> nhom) {
    final e = _loi.where(nhom.contains).firstOrNull;
    return e == null ? null : chuLoiDiem(context.l10n, e);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_choViTri) {
      ref.listen(viTriDiemProvider, (_, v) {
        if (v is ViTriCo && _choViTri) _dienViTri(v.viTri);
      });
      final v = ref.read(viTriDiemProvider);
      if (v is ViTriCo) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _choViTri) _dienViTri(v.viTri);
        });
      }
    }
    const khe = SizedBox(height: LbSpacing.md);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.diem == null ? l.wpNewTitle : l.wpEditTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(LbSpacing.md),
              children: [
                TextField(
                  key: const ValueKey('o-ten'),
                  controller: _ten,
                  maxLength: tenToiDa,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l.wpName,
                    errorText: _loiCua({LoiDiem.tenTrong, LoiDiem.tenDai}),
                  ),
                ),
                khe,
                TheViTriDiem(onDung: _dienViTri, dangCho: _choViTri),
                khe,
                _OSo(
                  khoa: 'o-vi-do',
                  dk: _viDo,
                  nhan: l.wpLat,
                  loi: _loiCua({LoiDiem.viDo}),
                ),
                khe,
                _OSo(
                  khoa: 'o-kinh-do',
                  dk: _kinhDo,
                  nhan: l.wpLon,
                  loi: _loiCua({LoiDiem.kinhDo}),
                ),
                khe,
                _OSo(
                  khoa: 'o-cao-do',
                  dk: _caoDo,
                  nhan: l.wpAlt,
                  loi: _loiCua({LoiDiem.caoDo}),
                ),
                khe,
                TextField(
                  key: const ValueKey('o-ghi-chu'),
                  controller: _ghiChu,
                  minLines: 2,
                  maxLines: 6,
                  maxLength: ghiChuToiDa,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l.wpNote,
                    alignLabelWithHint: true,
                    errorText: _loiCua({LoiDiem.ghiChuDai}),
                  ),
                ),
                khe,
                Text(l.wpPhotos, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: LbSpacing.xs),
                NgheAnhDiem(
                  // Điểm mới: id rỗng -> chưa có ảnh cũ.
                  id: widget.diem?.id ?? '',
                  builder: (context, tatCa) {
                    final cuAnh = tatCa
                        .where((a) => !_xoaAnh.contains(a.id))
                        .toList();
                    final soAnh = cuAnh.length + _anhMoi.length;
                    return Wrap(
                      spacing: LbSpacing.xs,
                      runSpacing: LbSpacing.xs,
                      children: [
                        for (final (i, a) in cuAnh.indexed)
                          _AnhNho(
                            anh: a.duLieu,
                            nhan: l.wpPhotoSemantics(i + 1),
                            onXoa: () => setState(() => _xoaAnh.add(a.id)),
                          ),
                        for (final (i, a) in _anhMoi.indexed)
                          _AnhNho(
                            anh: a.duLieu,
                            nhan: l.wpPhotoSemantics(cuAnh.length + i + 1),
                            onXoa: () => setState(() => _anhMoi.removeAt(i)),
                          ),
                        if (soAnh < anhToiDa)
                          OutlinedButton.icon(
                            key: const ValueKey('them-anh'),
                            onPressed: _themAnh,
                            icon: const LbIcon(IconDiem.anh),
                            label: Text(l.wpAddPhoto),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: LbSpacing.xs),
                Text(
                  l.wpPhotoHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: LbSpacing.lg),
                FilledButton(
                  key: const ValueKey('luu-diem'),
                  onPressed: _dangLuu ? null : _luu,
                  child: Text(l.wpSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OSo extends StatelessWidget {
  const new({
    required this.khoa,
    required this.dk,
    required this.nhan,
    this.loi,
  });

  final String khoa;
  final TextEditingController dk;
  final String nhan;
  final String? loi;

  @override
  Widget build(BuildContext context) => TextField(
    key: ValueKey(khoa),
    controller: dk,
    keyboardType: const TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    ),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
    decoration: InputDecoration(labelText: nhan, errorText: loi),
  );
}

class _AnhNho extends StatelessWidget {
  const new({required this.anh, required this.nhan, required this.onXoa});

  final Uint8List anh;
  final String nhan;
  final VoidCallback onXoa;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(LbRadius.sm),
            child: Image.memory(
              anh,
              fit: BoxFit.cover,
              cacheWidth: 288,
              semanticLabel: nhan,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: IconButton.filledTonal(
              tooltip: l.wpRemovePhoto,
              onPressed: onXoa,
              icon: const LbIcon(IconDiem.xoa, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
