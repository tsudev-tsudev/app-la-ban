import 'package:flutter/widgets.dart';

/// Ô dành sẵn cố định cho nội dung đổi qua lại (cảnh báo / bình thường /
/// đang tải): MỌI phương án đều được đặt bố cục, ô lấy kích thước lớn nhất
/// nên khi đổi [chiSo] layout bên dưới không nhảy. Chuyển bằng crossfade,
/// tức thì khi Reduce motion.
class LbOCoDinh extends StatelessWidget {
  const new({
    required this.chiSo,
    required this.phuongAn,
    this.thoiGian = const Duration(milliseconds: 200),
    this.canh = AlignmentDirectional.topStart,
    super.key,
  });

  /// Phương án đang hiện (chỉ số trong [phuongAn]); ngoài dải thì ẩn hết.
  final int chiSo;
  final List<Widget> phuongAn;
  final Duration thoiGian;
  final AlignmentGeometry canh;

  @override
  Widget build(BuildContext context) {
    final giam = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      alignment: canh,
      children: [
        for (var i = 0; i < phuongAn.length; i++)
          ExcludeSemantics(
            excluding: i != chiSo,
            child: IgnorePointer(
              ignoring: i != chiSo,
              child: AnimatedOpacity(
                opacity: i == chiSo ? 1 : 0,
                duration: giam ? Duration.zero : thoiGian,
                curve: Curves.easeInOut,
                child: phuongAn[i],
              ),
            ),
          ),
      ],
    );
  }
}
