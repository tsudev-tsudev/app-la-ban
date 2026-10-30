import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waypoint_feature/src/du_lieu/kho_diem.dart';
import 'package:waypoint_feature/src/providers.dart';

/// Dựng theo danh sách ảnh của điểm [id] (nghe kho, tự cập nhật). Ảnh chỉ
/// nạp khi màn cần - danh sách điểm không giữ ảnh trong bộ nhớ.
class NgheAnhDiem extends ConsumerStatefulWidget {
  const new({required this.id, required this.builder, super.key});

  final String id;
  final Widget Function(BuildContext context, List<AnhDiemMoc> anh) builder;

  @override
  ConsumerState<NgheAnhDiem> createState() => _NgheAnhDiemState();
}

class _NgheAnhDiemState extends ConsumerState<NgheAnhDiem> {
  late final Stream<List<AnhDiemMoc>> _luong =
      ref.read(khoDiemProvider)?.theoDoiAnh(widget.id) ??
      Stream.value(const []);

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _luong,
    builder: (context, snap) =>
        widget.builder(context, snap.data ?? const <AnhDiemMoc>[]),
  );
}
