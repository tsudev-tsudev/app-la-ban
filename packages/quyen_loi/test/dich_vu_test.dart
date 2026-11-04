import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quyen_loi/quyen_loi.dart';

final class CuaHangGia implements CuaHang {
  bool coBilling = true;
  bool moDuoc = true;
  List<GoiBan> goi = const [
    GoiBan(sanPham: SanPham.proNam, giaHienThi: '99.000 đ', ngayDungThu: 7),
    GoiBan(sanPham: SanPham.proVinhVien, giaHienThi: '149.000 đ'),
  ];
  List<GiaoDich> quaKhu = const [];
  List<GiaoDich> chuaXong = const [];
  final daHoanTat = <String>[];
  final daMua = <(SanPham, String)>[];
  final luong = StreamController<List<GiaoDich>>.broadcast();

  @override
  Future<bool> khaDung() async => coBilling;

  @override
  Future<List<GoiBan>> taiGoi() async => goi;

  @override
  Stream<List<GiaoDich>> get capNhat => luong.stream;

  @override
  Future<bool> mua(GoiBan goi, {required String maTaiKhoan}) async {
    daMua.add((goi.sanPham, maTaiKhoan));
    return moDuoc;
  }

  @override
  Future<List<GiaoDich>> khoiPhuc() async => quaKhu;

  @override
  Future<List<GiaoDich>> chuaXacNhan() async => chuaXong;

  @override
  Future<void> hoanTat(GiaoDich g) async => daHoanTat.add(g.token);
}

const _pro = QuyenLoi(pro: true, khongQuangCao: true, hetHan: 10000);

GiaoDich _gd(String token, {LoaiGiaoDich loai = LoaiGiaoDich.daMua}) =>
    GiaoDich(maSanPham: 'pro_nam', token: token, loai: loai, canHoanTat: true);

void main() {
  late CuaHangGia ch;
  late KhoQuyenLoiBoNho kho;
  late List<(SanPham, String)> guiMayChu;
  late KetQuaXacMinh traVe;
  var gio = 1000;

  DichVuQuyenLoi tao() => DichVuQuyenLoi(
    cuaHang: ch,
    kho: kho,
    maTaiKhoan: () => maTaiKhoanTuCaiDat('cai-dat-1'),
    dongHo: () => gio,
    xacMinh: (sp, token) async {
      guiMayChu.add((sp, token));
      return traVe;
    },
  )..batDau();

  setUp(() {
    ch = CuaHangGia();
    kho = KhoQuyenLoiBoNho();
    guiMayChu = [];
    traVe = (quyenLoi: _pro, loi: null);
    gio = 1000;
  });

  test('mã tài khoản: 64 hex, ổn định, không lộ định danh cài đặt', () {
    final m = maTaiKhoanTuCaiDat('abc');
    expect(m, hasLength(64));
    expect(m, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(m, maTaiKhoanTuCaiDat('abc'));
    expect(m, isNot(contains('abc')));
  });

  test(
    'mua: Play trả giao dịch -> máy chủ xác minh -> lưu + hoàn tất',
    () async {
      final dv = tao();
      await dv.taiGoi();
      expect(dv.mua.giaiDoan, GiaiDoanMua.sanSang);
      await dv.muaGoi(dv.mua.goi.first);
      expect(dv.mua.giaiDoan, GiaiDoanMua.dangMua);
      expect(ch.daMua.single.$1, SanPham.proNam);
      ch.luong.add([_gd('tok-1')]);
      await pumpEventQueue();
      expect(guiMayChu.single, (SanPham.proNam, 'tok-1'));
      expect(ch.daHoanTat, ['tok-1']);
      expect(dv.mua.giaiDoan, GiaiDoanMua.thanhCong);
      expect(dv.trangThai.coPro, isTrue);
      // Lưu bền: dịch vụ mới đọc lại được.
      expect(tao().trangThai.coPro, isTrue);
    },
  );

  test(
    'máy chủ từ chối -> KHÔNG hoàn tất (Play tự hoàn tiền), báo lỗi',
    () async {
      traVe = (quyenLoi: null, loi: LoiMua.quaSoThietBi);
      final dv = tao();
      await dv.taiGoi();
      await dv.muaGoi(dv.mua.goi.first);
      ch.luong.add([_gd('tok-2')]);
      await pumpEventQueue();
      expect(ch.daHoanTat, isEmpty);
      expect(dv.mua.loi, LoiMua.quaSoThietBi);
      expect(dv.trangThai.coPro, isFalse);
    },
  );

  test('huỷ / chờ thanh toán không gửi máy chủ', () async {
    final dv = tao();
    await dv.taiGoi();
    await dv.muaGoi(dv.mua.goi.first);
    ch.luong.add([_gd('x', loai: LoaiGiaoDich.huy)]);
    await pumpEventQueue();
    expect(dv.mua.giaiDoan, GiaiDoanMua.sanSang);
    await dv.muaGoi(dv.mua.goi.first);
    ch.luong.add([_gd('y', loai: LoaiGiaoDich.choThanhToan)]);
    await pumpEventQueue();
    expect(dv.mua.giaiDoan, GiaiDoanMua.choThanhToan);
    expect(guiMayChu, isEmpty);
  });

  test('Play không có -> không khả dụng; không mở được luồng -> lỗi', () async {
    ch.coBilling = false;
    final dv = tao();
    await dv.taiGoi();
    expect(dv.mua.giaiDoan, GiaiDoanMua.khongKhaDung);
    ch
      ..coBilling = true
      ..moDuoc = false;
    await dv.taiGoi();
    await dv.muaGoi(dv.mua.goi.first);
    expect(dv.mua.loi, LoiMua.cuaHang);
  });

  test('khôi phục: không có giao dịch -> lỗi riêng', () async {
    final dv = tao();
    await dv.taiGoi();
    await dv.khoiPhuc();
    expect(dv.mua.loi, LoiMua.khongCoGiaoDich);
    expect(dv.mua.dangKhoiPhuc, isFalse);
  });

  test('khôi phục: giao dịch còn hiệu lực -> pro', () async {
    ch.quaKhu = [_gd('cu', loai: LoaiGiaoDich.khoiPhuc)];
    final dv = tao();
    await dv.taiGoi();
    await dv.khoiPhuc();
    expect(guiMayChu.single.$2, 'cu');
    expect(dv.mua.giaiDoan, GiaiDoanMua.thanhCong);
    expect(dv.trangThai.coPro, isTrue);
  });

  test('giao dịch dở (chưa xác nhận) được gửi lại khi mở app', () async {
    ch.chuaXong = [_gd('do-dang')];
    final dv = tao();
    await dv.thuLaiChuaXacNhan();
    expect(guiMayChu.single.$2, 'do-dang');
    expect(ch.daHoanTat, ['do-dang']);
    expect(dv.trangThai.coPro, isTrue);
    // Thử nền không đổi màn Paywall.
    expect(dv.mua.giaiDoan, GiaiDoanMua.dangTai);
  });

  test('cùng token về hai lần đồng thời chỉ gửi một lần', () async {
    final cho = Completer<KetQuaXacMinh>();
    final dv = DichVuQuyenLoi(
      cuaHang: ch,
      kho: kho,
      maTaiKhoan: () => 'm',
      xacMinh: (sp, token) {
        guiMayChu.add((sp, token));
        return cho.future;
      },
    )..batDau();
    ch.luong
      ..add([_gd('t')])
      ..add([_gd('t')]);
    await pumpEventQueue();
    cho.complete(traVe);
    await pumpEventQueue();
    expect(guiMayChu, hasLength(1));
    dv.dispose();
  });

  test(
    '/v1/status cập nhật quyền lợi; hết hạn + ân hạn theo đồng hồ',
    () async {
      final dv = tao();
      var bao = 0;
      dv.addListener(() => bao++);
      await dv.capNhatTuMayChu(_pro);
      expect(bao, 1);
      expect(dv.trangThai.muc, MucQuyenLoi.pro);
      await dv.capNhatTuMayChu(_pro);
      expect(bao, 1, reason: 'không đổi -> không báo');
      gio = 10000 + 1;
      expect(dv.trangThai.muc, MucQuyenLoi.anHan);
      await dv.capNhatTuMayChu(QuyenLoi.mienPhi);
      expect(dv.trangThai.coPro, isFalse);
    },
  );
}
