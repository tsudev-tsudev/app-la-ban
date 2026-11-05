import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quyen_loi/quyen_loi.dart';
import 'package:test_kit/test_kit.dart';

import 'dich_vu_test.dart' show CuaHangGia;

const _goi = [
  GoiBan(
    sanPham: SanPham.proNam,
    giaHienThi: '99.000 ₫',
    donVi: DonViKy.nam,
    ngayDungThu: 7,
  ),
  GoiBan(
    sanPham: SanPham.proThang,
    giaHienThi: '19.000 ₫',
    donVi: DonViKy.thang,
  ),
  GoiBan(sanPham: SanPham.proVinhVien, giaHienThi: '149.000 ₫'),
];

void main() {
  setUpAll(napFontThat);

  DichVuQuyenLoi taoDv({
    CuaHangGia? ch,
    KetQuaXacMinh kq = (
      quyenLoi: const QuyenLoi(pro: true, khongQuangCao: true),
      loi: null,
    ),
  }) => DichVuQuyenLoi(
    cuaHang: ch ?? (CuaHangGia()..goi = _goi),
    kho: KhoQuyenLoiBoNho(),
    maTaiKhoan: () => 'm',
    dongHo: () => DateTime.utc(2026, 11, 4).millisecondsSinceEpoch,
    xacMinh: (_, _) async => kq,
  )..batDau();

  // Đã tải gói trước khung đầu: nút mua bật ngay, không chụp giữa hoạt ảnh.
  late DichVuQuyenLoi san;
  setUp(() async {
    san = taoDv();
    await san.taiGoi();
  });

  Widget dung(OMaTran o, {DichVuQuyenLoi? dv}) => ProviderScope(
    overrides: [
      dichVuQuyenLoiProvider.overrideWithValue(dv ?? san),
      moQuanLyGoiProvider.overrideWithValue(() async => true),
    ],
    child: khungThu(const ManPro(), o: o),
  );

  testWidgets('trợ năng: vùng chạm, nhãn, tương phản', (tester) async {
    await kiemTroNang(tester, dung);
  });

  testWidgets('ma trận: không tràn', (tester) async {
    await kiemMaTran(tester, dung);
  });

  testWidgets('golden', (tester) async {
    await chupGolden(tester, 'man_pro', dung);
  });

  testWidgets('giá từ Play + điều khoản tự gia hạn + dùng thử', (tester) async {
    await tester.pumpWidget(dung(oChup.first));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('99.000 ₫ / năm'), findsWidgets);
    expect(find.textContaining('7 ngày dùng thử miễn phí'), findsOneWidget);
    expect(find.text('Bắt đầu dùng thử miễn phí'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Thanh toán và gói thuê bao'),
      200,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('goi-pro_vinh_vien')));
    await tester.tap(find.byKey(const ValueKey('goi-pro_vinh_vien')));
    await tester.pump();
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.textContaining('không tự gia hạn'), findsOneWidget);
  });

  testWidgets('mua -> Play -> máy chủ xác minh -> thành công', (tester) async {
    final ch = CuaHangGia()..goi = _goi;
    final dv = taoDv(ch: ch);
    await tester.pumpWidget(dung(oChup.first, dv: dv));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('mua-pro')));
    await tester.pump();
    expect(ch.daMua.single.$1, SanPham.proNam);
    ch.luong.add([
      const GiaoDich(
        maSanPham: 'pro_nam',
        token: 'tok-abcdef',
        loai: LoaiGiaoDich.daMua,
        canHoanTat: true,
      ),
    ]);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Cảm ơn bạn! La bàn Pro đã được bật.'), findsOneWidget);
    expect(find.text('Bạn đang dùng La bàn Pro'), findsOneWidget);
    expect(find.byKey(const ValueKey('mua-pro')), findsNothing);
  });

  testWidgets('lỗi máy chủ hiện thông báo, đóng được', (tester) async {
    final ch = CuaHangGia()..goi = _goi;
    final dv = taoDv(
      ch: ch,
      kq: (quyenLoi: null, loi: LoiMua.khongPhaiBanPlay),
    );
    await tester.pumpWidget(dung(oChup.first, dv: dv));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('mua-pro')));
    await tester.pump();
    ch.luong.add([
      const GiaoDich(
        maSanPham: 'pro_nam',
        token: 'tok-abcdef',
        loai: LoaiGiaoDich.daMua,
      ),
    ]);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('không đến từ Google Play'), findsOneWidget);
    expect(ch.daHoanTat, isEmpty);
    await tester.ensureVisible(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.textContaining('không đến từ Google Play'), findsNothing);
  });

  testWidgets('không có Play -> thông báo + thử lại', (tester) async {
    final ch = CuaHangGia()..coBilling = false;
    await tester.pumpWidget(dung(oChup.first, dv: taoDv(ch: ch)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('chưa sẵn sàng'), findsOneWidget);
    expect(find.byKey(const ValueKey('mua-pro')), findsOneWidget);
  });

  testWidgets('mục Cài đặt: miễn phí / đang dùng', (tester) async {
    final dv = taoDv();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dichVuQuyenLoiProvider.overrideWithValue(dv)],
        child: khungThu(const Scaffold(body: MucPro()), o: oChup.first),
      ),
    );
    expect(find.text('Gỡ quảng cáo, ủng hộ phát triển'), findsOneWidget);
    await dv.capNhatTuMayChu(const QuyenLoi(pro: true, khongQuangCao: true));
    await tester.pump();
    expect(find.text('Đang dùng'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('muc-pro')));
    await tester.pumpAndSettle();
    expect(find.byType(ManPro), findsOneWidget);
  });

  group('MucBanQuyenPro (M2, Q56)', () {
    DichVuQuyenLoi dvPro() => DichVuQuyenLoi(
      cuaHang: const CuaHangKhongBan(),
      kho: KhoQuyenLoiBoNho(),
      maTaiKhoan: () => 'm',
      dongHo: () => DateTime.utc(2026, 11, 5).millisecondsSinceEpoch,
      xacMinh: (_, _) async => (quyenLoi: null, loi: LoiMua.mayChu),
    )..batDau();

    Widget dungMuc(DichVuQuyenLoi dv, Future<bool?> Function()? kp) =>
        ProviderScope(
          overrides: [
            dichVuQuyenLoiProvider.overrideWithValue(dv),
            khacPhucBanQuyenProvider.overrideWithValue(kp),
          ],
          child: khungThu(
            const Scaffold(body: MucBanQuyenPro()),
            o: oChup.first,
          ),
        );

    testWidgets('chưa xác minh -> chạm mở khắc phục, báo kết quả', (
      tester,
    ) async {
      var goi = 0;
      bool? kq = true;
      await tester.pumpWidget(
        dungMuc(dvPro(), () async {
          goi++;
          return kq;
        }),
      );
      expect(
        find.text('Chưa xác minh - chạm để tải bản chính thức từ Google Play'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('muc-ban-quyen-pro')));
      await tester.pump();
      expect(goi, 1);
      expect(
        find.text('Đã gửi yêu cầu xác minh lại bản quyền.'),
        findsOneWidget,
      );
      kq = null;
      await tester.tap(find.byKey(const ValueKey('muc-ban-quyen-pro')));
      await tester.pump();
      expect(goi, 2);
    });

    testWidgets('đã có pro_app -> hiện đã xác minh, không chạm được', (
      tester,
    ) async {
      final dv = dvPro();
      var goi = 0;
      await tester.pumpWidget(
        dungMuc(dv, () async {
          goi++;
          return true;
        }),
      );
      await dv.capNhatTuMayChu(const QuyenLoi(pro: true, khongQuangCao: true));
      await tester.pump();
      expect(
        find.text('Đã xác minh qua Google Play - đủ mọi tính năng Pro'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('muc-ban-quyen-pro')));
      await tester.pump();
      expect(goi, 0);
    });
  });

  test('CuaHangKhongBan: không bán, không giao dịch', () async {
    const ch = CuaHangKhongBan();
    expect(await ch.khaDung(), isFalse);
    expect(await ch.taiGoi(), isEmpty);
    expect(await ch.khoiPhuc(), isEmpty);
    expect(await ch.chuaXacNhan(), isEmpty);
    expect(await ch.capNhat.isEmpty, isTrue);
  });
}
