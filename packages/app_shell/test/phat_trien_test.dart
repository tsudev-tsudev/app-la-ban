import 'package:app_shell/src/kenh.dart';
import 'package:app_shell/src/phat_trien.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network/network.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:test_kit/test_kit.dart';

import 'ho_tro.dart';

final class _Kenh implements KenhPhatTrien {
  TrangThaiPhatTrien t = const TrangThaiPhatTrien(devMode: true, adb: true);
  int soLanMo = 0;
  bool moDuoc = true;

  @override
  Future<TrangThaiPhatTrien> doc() async => t;

  @override
  Future<bool> moCaiDat() async {
    soLanMo++;
    return moDuoc;
  }
}

void main() {
  late _Kenh kenh;
  late GiamSatPhatTrien g;

  setUp(() {
    kenh = _Kenh();
    g = GiamSatPhatTrien(kenh: kenh, khoangNen: const Duration(days: 1));
  });
  tearDown(() => g.dispose());

  // Hẹn giờ kiểm lại của GiamSatPhatTrien chạy trong fake async: dừng trước
  // khi testWidgets kiểm "không còn timer".
  void tw(String ten, Future<void> Function(WidgetTester) than) =>
      testWidgets(ten, (tester) async {
        await than(tester);
        g.dung();
      });

  Widget app({
    bool prod = true,
    TinhTrangThietBi? tt,
    Set<String> tat = const {},
  }) => appThu(
    them: [
      giamSatPhatTrienProvider.overrideWithValue(g),
      banProdProvider.overrideWithValue(prod),
      tinhTrangProvider.overrideWithValue(tt),
      cauHinhTuXaProvider.overrideWithValue(
        tat.isEmpty
            ? null
            : CauHinhTuXa(
                phatHanh: 1,
                het: 1 << 40,
                toiThieu: 0,
                khuyenNghi: 0,
                tat: tat,
                pin: const [],
                gocThem: const [],
              ),
      ),
    ],
  );

  tw('prod bật -> chỉ còn màn chặn; tắt rồi Kiểm tra lại -> app trở lại', (
    tester,
  ) async {
    datHeThong(tester, oChup.first);
    await g.kiem();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('man-chan-phat-trien')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab/ban-do')), findsNothing);
    expect(find.text('Gỡ lỗi USB'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('mo-cai-dat-phat-trien')),
    );
    await tester.tap(find.byKey(const ValueKey('mo-cai-dat-phat-trien')));
    await tester.pump();
    expect(kenh.soLanMo, 1);
    kenh.t = TrangThaiPhatTrien.sach;
    await tester.ensureVisible(
      find.byKey(const ValueKey('kiem-lai-phat-trien')),
    );
    await tester.tap(find.byKey(const ValueKey('kiem-lai-phat-trien')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('man-chan-phat-trien')), findsNothing);
    expect(find.byKey(const ValueKey('tab/ban-do')), findsOneWidget);
  });

  tw('đang chặn: tự kiểm lại mỗi 2 giây (tắt bằng Cài đặt nhanh)', (
    tester,
  ) async {
    datHeThong(tester, oChup.first);
    await tester.pumpWidget(app());
    await g.kiem();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('man-chan-phat-trien')), findsOneWidget);
    kenh.t = TrangThaiPhatTrien.sach;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('man-chan-phat-trien')), findsNothing);
  });

  tw('máy đã tắt nhưng máy chủ còn báo -> vẫn chặn, giải thích cần mạng', (
    tester,
  ) async {
    datHeThong(tester, oChup.first);
    kenh.t = TrangThaiPhatTrien.sach;
    await g.kiem();
    await tester.pumpWidget(
      app(
        tt: const TinhTrangThietBi(
          trangThai: TrangThaiThietBi.clean,
          mucTin: MucTin.device,
          cheDoPhatTrien: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('man-chan-phat-trien')), findsOneWidget);
    expect(find.textContaining('Máy chủ vẫn ghi nhận'), findsOneWidget);
  });

  tw('staging / dev chỉ ghi nhận; kill-switch chanDevMode tắt màn chặn', (
    tester,
  ) async {
    datHeThong(tester, oChup.first);
    await g.kiem();
    await tester.pumpWidget(app(prod: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('man-chan-phat-trien')), findsNothing);
    await tester.pumpWidget(app(tat: {khoaTatChanPhatTrien}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('man-chan-phat-trien')), findsNothing);
  });

  tw('ma trận + trợ năng: màn chặn không tràn', (tester) async {
    await g.kiem();
    await kiemMaTran(tester, (o) {
      datHeThong(tester, o);
      return app();
    });
    await kiemTroNang(tester, (o) {
      datHeThong(tester, o);
      return app();
    });
  });

  tw('golden: màn chặn chế độ Nhà phát triển', (tester) async {
    await g.kiem();
    await chupGolden(tester, 'man_chan_phat_trien', (o) {
      datHeThong(tester, o);
      return app();
    });
  });
}
