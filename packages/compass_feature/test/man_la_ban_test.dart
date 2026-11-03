import 'dart:async';

import 'package:compass_feature/compass_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';
import 'package:test_kit/test_kit.dart';

HuongDoc doc({
  double phuongVi = 127.4,
  MucTinCay muc = MucTinCay.cao,
  bool nhieuTu = false,
  bool canHieuChuan = false,
  int ms = 0,
}) => HuongDoc(
  phuongVi: phuongVi,
  phuongViTho: phuongVi,
  doc: 3.2,
  lan: -1.6,
  theoCamera: false,
  muc: muc,
  nhieuTu: nhieuTu,
  canHieuChuan: canHieuChuan,
  cuongDoTu: 45,
  nguon: NguonHuong.madgwick,
  dungYen: false,
  tNs: ms * 1000000,
);

Widget dung(OMaTran o, List<Override> ghiDe) => ProviderScope(
  overrides: ghiDe,
  child: khungThu(const ManLaBan(), o: o),
);

/// Hà Nội, ngày cố định -> độ lệch WMM ổn định cho golden.
const haNoi = ViTriDiaLy(viDo: 21.0285, kinhDo: 105.8542, doCaoM: 15);

class ViTriThu extends ViTriNotifier {
  @override
  ViTriDiaLy? build() => haNoi;
}

final List<Override> coViTri = [
  viTriProvider.overrideWith(ViTriThu.new),
  dongHoProvider.overrideWithValue(() => DateTime.utc(2026, 10, 28)),
];

/// Kho tuỳ chọn trong bộ nhớ với giá trị ban đầu [t].
Override tuyChon(TuyChonLaBan t) =>
    khoTuyChonLaBanProvider.overrideWithValue(KhoTuyChonLaBanBoNho(t));

Override coHuong(HuongDoc h) =>
    huongProvider.overrideWith((ref) => Stream.value(h));

void main() {
  setUpAll(napFontThat);

  testWidgets('trợ năng: vùng chạm, nhãn, tương phản', (tester) async {
    await kiemTroNang(
      tester,
      (o) => dung(o, [
        coHuong(doc(muc: MucTinCay.thap, nhieuTu: true)),
        ...coViTri,
      ]),
    );
  });

  testWidgets('ma trận 12 kích thước x theme x ngôn ngữ x cỡ chữ: không tràn', (
    tester,
  ) async {
    // Trường hợp dài nhất: có cảnh báo nhiễu từ.
    final ghiDe = [coHuong(doc(muc: MucTinCay.thap, nhieuTu: true))];
    await kiemMaTran(tester, (o) => dung(o, ghiDe));
  });

  testWidgets('golden (bắc thực, Hà Nội)', (tester) async {
    final ghiDe = [coHuong(doc()), ...coViTri];
    await chupGolden(tester, 'man_la_ban', (o) => dung(o, ghiDe));
  });

  testWidgets('golden cần hiệu chuẩn', (tester) async {
    final ghiDe = [
      coHuong(doc(phuongVi: 300, muc: MucTinCay.thap, canHieuChuan: true)),
    ];
    await chupGolden(
      tester,
      'man_la_ban_hieu_chuan',
      (o) => dung(o, ghiDe),
      dsO: [oChup.first],
    );
  });

  testWidgets('A9c: nhiễu từ bật / tắt theo từng mẫu - cảnh báo và nhãn độ '
      'tin cậy không nhấp nháy, mặt la bàn không nhảy', (tester) async {
    final ctl = StreamController<HuongDoc>();
    addTearDown(() => unawaited(ctl.close()));
    await tester.pumpWidget(
      dung(oChup.first, [
        huongProvider.overrideWith((ref) => ctl.stream),
        ...coViTri,
      ]),
    );
    ctl.add(doc());
    await tester.pump(const Duration(seconds: 1));
    final mat = find.byType(MatLaBan);
    final canhBao = find.text(
      'Nhiễu từ: tránh xa nam châm, loa, ốp lưng có nam châm hoặc vật kim '
      'loại lớn.',
    );
    double? mo() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: canhBao, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    final viTriMat = tester.getRect(mat);
    expect(mo(), 0);
    expect(find.text('Độ tin cậy: Cao'), findsOneWidget);

    var doiCanhBao = 0;
    var doiNhan = 0;
    var truocMo = mo();
    var truocCao = true;
    for (var ms = 100; ms <= 5000; ms += 100) {
      final nhieu = (ms ~/ 100).isOdd;
      ctl.add(
        doc(
          muc: nhieu ? MucTinCay.thap : MucTinCay.cao,
          nhieuTu: nhieu,
          ms: ms,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(mat), viTriMat, reason: '$ms ms');
      if (mo() != truocMo) doiCanhBao++;
      truocMo = mo();
      final cao = find.text('Độ tin cậy: Cao').evaluate().isNotEmpty;
      if (cao != truocCao) doiNhan++;
      truocCao = cao;
    }
    expect(doiCanhBao, 1);
    expect(doiNhan, 1);

    // Hết nhiễu hẳn: tắt sau giữ tối thiểu + chờ, mặt vẫn đứng yên.
    for (var ms = 5100; ms <= 8000; ms += 100) {
      ctl.add(doc(ms: ms));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(mat), viTriMat);
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(mo(), 0);
    expect(find.text('Độ tin cậy: Cao'), findsOneWidget);
  });

  testWidgets('hiện số độ, hướng, độ tin cậy, góc nghiêng (vi)', (
    tester,
  ) async {
    await tester.pumpWidget(dung(oChup.first, [coHuong(doc())]));
    await tester.pump();
    expect(find.textContaining('127,4°'), findsOneWidget);
    expect(find.textContaining('ĐN'), findsWidgets);
    expect(find.text('Từ trường 45 µT'), findsOneWidget);
    expect(find.text('Độ tin cậy: Cao'), findsOneWidget);
    expect(find.text('Ngóc 3° · Nghiêng -2°'), findsOneWidget);
    expect(find.bySemanticsLabel('Hướng 127 độ, Đông Nam'), findsOneWidget);
  });

  testWidgets('giảm chuyển động: mặt số nhảy thẳng tới hướng mới', (
    tester,
  ) async {
    Widget mat(double pv, {required bool giam}) => khungThu(
      MediaQuery(
        data: MediaQueryData(disableAnimations: giam),
        child: Builder(
          builder: (context) => MatLaBan(
            phuongVi: pv,
            canh: 200,
            nhan8: const ['B', 'ĐB', 'Đ', 'ĐN', 'N', 'TN', 'T', 'TB'],
            mau: MauMatLaBan.tuTheme(context),
          ),
        ),
      ),
      o: oChup.first,
    );
    double goc() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(MatLaBan),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .getRotation()
        .entry(1, 0);

    await tester.pumpWidget(mat(0, giam: true));
    await tester.pumpWidget(mat(90, giam: true));
    await tester.pump();
    // sin(-90°): đã tới đích ngay khung đầu, không còn khung nào chờ vẽ.
    expect(goc(), closeTo(-1, 1e-6));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(mat(180, giam: false));
    await tester.pump();
    expect(goc(), closeTo(-1, 1e-6));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(goc(), closeTo(0, 1e-6));
  });

  testWidgets('đang khởi động / không có la bàn / lỗi khác', (tester) async {
    final cho = StreamController<HuongDoc>();
    addTearDown(cho.close);
    await tester.pumpWidget(
      dung(oChup.first, [huongProvider.overrideWith((ref) => cho.stream)]),
    );
    expect(find.text('Đang khởi động cảm biến...'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      dung(oChup.first, [
        huongProvider.overrideWith(
          (ref) => Stream.error(const NgoaiLeCamBien(LoiCamBien.khongCoLaBan)),
        ),
      ]),
    );
    await tester.pump();
    expect(find.textContaining('không có cảm biến la bàn'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      dung(oChup.first, [
        huongProvider.overrideWith((ref) => Stream.error(StateError('x'))),
      ]),
    );
    await tester.pump();
    expect(find.textContaining('Không đọc được cảm biến'), findsOneWidget);
  });

  testWidgets('nối thật với bộ hợp nhất qua dữ liệu ghi sẵn', (tester) async {
    // Máy nằm ngửa, đỉnh máy chỉ hướng Đông: gia tốc +Z, từ trường bắc từ
    // nằm về phía -X của máy.
    final ds = [
      for (var i = 0; i < 20; i++) ...[
        MauCamBien(LoaiMau.giaToc, i * 10000000, z: 9.81),
        MauCamBien(LoaiMau.tu, i * 10000000, x: -39, z: -22),
      ],
    ];
    final nguon = NguonCamBienGhiSan(
      [maHoaLo(ds)],
      khaNang: (
        xoayVector: false,
        xoayGame: false,
        tu: true,
        giaToc: true,
        conQuay: false,
        apSuat: false,
      ),
    );
    await tester.pumpWidget(
      dung(oChup.first, [
        nguonCamBienProvider.overrideWithValue(nguon),
        dichVuHuongProvider.overrideWith(
          (ref) =>
              DichVuHuong(ref.watch(nguonCamBienProvider), dungIsolate: false),
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('90,0°'), findsOneWidget);
  });

  testWidgets('app xuống nền -> thôi nghe cảm biến, trở lại -> nghe lại', (
    tester,
  ) async {
    var soLanNghe = 0;
    var soLanHuy = 0;
    final ghiDe = [
      huongProvider.overrideWith((ref) {
        soLanNghe++;
        ref.onDispose(() => soLanHuy++);
        return Stream.value(doc());
      }),
    ];
    await tester.pumpWidget(dung(oChup.first, ghiDe));
    await tester.pump();
    expect(soLanNghe, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    expect(soLanHuy, 1);
    expect(find.textContaining('127,4°'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(soLanNghe, 2);
    expect(find.textContaining('127,4°'), findsOneWidget);
  });

  testWidgets('tab ẩn (TickerMode tắt) không nghe cảm biến', (tester) async {
    var soLanNghe = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          huongProvider.overrideWith((ref) {
            soLanNghe++;
            return Stream.value(doc());
          }),
        ],
        child: khungThu(
          const TickerMode(enabled: false, child: ManLaBan()),
          o: oChup.first,
        ),
      ),
    );
    await tester.pump();
    expect(soLanNghe, 0);
  });

  testWidgets('bắc thực: cộng độ lệch WMM tại Hà Nội, hiện độ lệch Tây', (
    tester,
  ) async {
    await tester.pumpWidget(dung(oChup.first, [coHuong(doc()), ...coViTri]));
    await tester.pump();
    final kq = tinhTuTruong(
      HeSoWmm.wmm2025,
      viDo: haNoi.viDo,
      kinhDo: haNoi.kinhDo,
      doCaoKm: 0.015,
      nam: namThapPhan(DateTime.utc(2026, 10, 28)),
    );
    expect(kq.doLech, lessThan(0));
    final mongDoi = tinhHuongHienThi(
      127.4,
      muonBacThuc: true,
      tuTruong: kq,
    ).soDo01;
    final chu = mongDoi.toStringAsFixed(1).replaceAll('.', ',');
    expect(find.textContaining('$chu°'), findsOneWidget);
    expect(
      find.textContaining(
        'Theo bắc thực · Độ lệch từ '
        '${kq.doLech.abs().toStringAsFixed(1).replaceAll('.', ',')}° Tây',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Chưa có vị trí'), findsNothing);
  });

  testWidgets('bắc thực nhưng chưa có vị trí -> theo bắc từ + ghi chú', (
    tester,
  ) async {
    await tester.pumpWidget(dung(oChup.first, [coHuong(doc())]));
    await tester.pump();
    expect(find.text('Theo bắc từ'), findsOneWidget);
    expect(find.textContaining('Chưa có vị trí'), findsOneWidget);
  });

  testWidgets('chọn bắc từ: không ghi chú vị trí', (tester) async {
    await tester.pumpWidget(
      dung(oChup.first, [
        coHuong(doc()),
        tuyChon(const TuyChonLaBan(bacThuc: false)),
      ]),
    );
    await tester.pump();
    expect(find.text('Theo bắc từ'), findsOneWidget);
    expect(find.textContaining('Chưa có vị trí'), findsNothing);
  });

  testWidgets('bảng tuỳ chọn: tắt bắc thực / rung, ghi vào kho', (
    tester,
  ) async {
    final kho = KhoTuyChonLaBanBoNho();
    await tester.pumpWidget(
      dung(oChup.first, [
        coHuong(doc()),
        ...coViTri,
        khoTuyChonLaBanProvider.overrideWithValue(kho),
      ]),
    );
    await tester.pump();
    expect(find.textContaining('Theo bắc thực'), findsOneWidget);
    await tester.tap(find.byTooltip('Tuỳ chọn la bàn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắc thực'));
    await tester.pump();
    await tester.tap(find.text('Rung khi qua hướng chính'));
    await tester.pumpAndSettle();
    expect(kho.doc(), const TuyChonLaBan(bacThuc: false, rung: false));
    Navigator.of(tester.element(find.text('Bắc thực'))).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('Theo bắc từ'), findsOneWidget);
  });

  testWidgets('rung khi kim qua hướng chính; tắt rung thì im', (tester) async {
    for (final bat in [true, false]) {
      var soLan = 0;
      final cho = StreamController<HuongDoc>();
      addTearDown(cho.close);
      await tester.pumpWidget(
        dung(oChup.first, [
          huongProvider.overrideWith((ref) => cho.stream),
          tuyChon(TuyChonLaBan(bacThuc: false, rung: bat)),
          rungProvider.overrideWithValue(() => soLan++),
        ]),
      );
      for (final d in <double>[60, 66, 71, 80, 100, 116]) {
        cho.add(doc(phuongVi: d));
        await tester.pump();
      }
      // 60 -> 71 qua Đông (90° ở giữa cung 67,5-112,5), 116 qua Đông Nam.
      expect(soLan, bat ? 2 : 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('nút Hiệu chuẩn trong cảnh báo mở màn hiệu chuẩn', (
    tester,
  ) async {
    await tester.pumpWidget(
      dung(oChup.first, [coHuong(doc(muc: MucTinCay.thap, nhieuTu: true))]),
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(TextButton, 'Hiệu chuẩn').hitTestable(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ManHieuChuan), findsOneWidget);
    expect(find.text('Hiệu chuẩn la bàn'), findsOneWidget);
  });
}
