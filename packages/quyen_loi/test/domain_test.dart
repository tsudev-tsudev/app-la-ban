import 'package:flutter_test/flutter_test.dart';
import 'package:quyen_loi/quyen_loi.dart';

const int _ngay = 24 * 60 * 60 * 1000;

GiaiDoanGia _gd(int micros, String ky, {bool lap = true, int chuKy = 0}) =>
    GiaiDoanGia(
      giaMicros: micros,
      giaHienThi: micros == 0 ? 'Miễn phí' : '${micros ~/ 1000000} đ',
      kyHan: ky,
      soChuKy: chuKy,
      lapVoHan: lap,
    );

void main() {
  group('QuyenLoi.tuJson', () {
    test('đúng dạng Worker', () {
      expect(
        QuyenLoi.tuJson({'pro': true, 'khongQuangCao': true, 'hetHan': 5}),
        const QuyenLoi(pro: true, khongQuangCao: true, hetHan: 5),
      );
      expect(
        QuyenLoi.tuJson({'pro': true, 'khongQuangCao': true, 'hetHan': null})!
            .vinhVien,
        isTrue,
      );
    });
    test('sai dạng -> null', () {
      expect(QuyenLoi.tuJson(null), isNull);
      expect(QuyenLoi.tuJson({'pro': 1, 'khongQuangCao': true}), isNull);
      expect(
        QuyenLoi.tuJson({'pro': true, 'khongQuangCao': true, 'hetHan': '1'}),
        isNull,
      );
    });
  });

  group('tinhQuyenLoi (ân hạn offline)', () {
    const het = 100 * _ngay;
    const goi = QuyenLoi(pro: true, khongQuangCao: true, hetHan: het);

    test('chưa có / không pro -> miễn phí', () {
      expect(
        tinhQuyenLoi(daLuu: null, nhanLuc: null, bayGio: 0).muc,
        MucQuyenLoi.mienPhi,
      );
      expect(
        tinhQuyenLoi(daLuu: QuyenLoi.mienPhi, nhanLuc: 0, bayGio: 0).coPro,
        isFalse,
      );
    });
    test('còn hạn -> pro, không quảng cáo', () {
      final t = tinhQuyenLoi(daLuu: goi, nhanLuc: 0, bayGio: het - 1);
      expect(t.muc, MucQuyenLoi.pro);
      expect(t.khongQuangCao, isTrue);
    });
    test('quá hạn trong 3 ngày -> ân hạn; sau đó -> miễn phí', () {
      expect(
        tinhQuyenLoi(daLuu: goi, nhanLuc: 0, bayGio: het + 2 * _ngay).muc,
        MucQuyenLoi.anHan,
      );
      final sau = tinhQuyenLoi(daLuu: goi, nhanLuc: 0, bayGio: het + 4 * _ngay);
      expect(sau.muc, MucQuyenLoi.mienPhi);
      expect(sau.khongQuangCao, isFalse);
    });
    test('lùi đồng hồ không kéo dài hạn', () {
      final t = tinhQuyenLoi(
        daLuu: goi,
        nhanLuc: het + 5 * _ngay,
        bayGio: het - 10 * _ngay,
      );
      expect(t.muc, MucQuyenLoi.mienPhi);
    });
    test('vĩnh viễn giữ tới khi máy chủ báo khác', () {
      const vv = QuyenLoi(pro: true, khongQuangCao: true);
      expect(
        tinhQuyenLoi(daLuu: vv, nhanLuc: 0, bayGio: 9999 * _ngay).muc,
        MucQuyenLoi.pro,
      );
    });
  });

  group('ưu đãi gói đăng ký', () {
    final goc = UuDai(
      basePlan: 'nam',
      offerId: null,
      chiSo: 0,
      giaiDoan: [_gd(99000000000, 'P1Y')],
    );
    final dungThu = UuDai(
      basePlan: 'nam',
      offerId: 'thu-7-ngay',
      chiSo: 1,
      giaiDoan: [_gd(0, 'P1W', lap: false, chuKy: 1), _gd(99000000000, 'P1Y')],
    );
    final giamGia = UuDai(
      basePlan: 'nam',
      offerId: 'giam',
      chiSo: 2,
      giaiDoan: [_gd(1, 'P1Y', lap: false, chuKy: 1), _gd(99000000000, 'P1Y')],
    );

    test('ưu tiên dùng thử, rồi base plan, rồi offer khác', () {
      expect(chonUuDai([goc, giamGia, dungThu]), same(dungThu));
      expect(chonUuDai([giamGia, goc]), same(goc));
      expect(chonUuDai([giamGia]), same(giamGia));
      expect(chonUuDai(const []), isNull);
    });
    test('ngày dùng thử + giá gia hạn', () {
      expect(dungThu.ngayDungThu, 7);
      expect(goc.ngayDungThu, isNull);
      expect(dungThu.giaGiaHan!.kyHan, 'P1Y');
    });
    test('kỳ ISO 8601', () {
      expect(soNgayKyHan('P7D'), 7);
      expect(soNgayKyHan('P1M'), 30);
      expect(soNgayKyHan('x'), isNull);
      expect(donViKy('P1M'), DonViKy.thang);
      expect(donViKy('P12M'), DonViKy.nam);
      expect(donViKy('P1Y'), DonViKy.nam);
      expect(donViKy('P1W'), DonViKy.tuan);
    });
    test('mã sản phẩm khớp Worker', () {
      expect(SanPham.dsMa, {'pro_thang', 'pro_nam', 'pro_vinh_vien'});
      expect(SanPham.tuMa('pro_vinh_vien')!.dangKy, isFalse);
      expect(SanPham.tuMa('khac'), isNull);
    });
    test('sắp xếp gói theo thứ tự Paywall, bỏ trùng', () {
      const t = GoiBan(sanPham: SanPham.proThang, giaHienThi: 'a');
      const v = GoiBan(sanPham: SanPham.proVinhVien, giaHienThi: 'b');
      const n = GoiBan(sanPham: SanPham.proNam, giaHienThi: 'c');
      expect(sapXepGoi([v, t, n, t]), [n, t, v]);
    });
  });

  group('lỗi xác minh', () {
    test('mã Worker -> lỗi hiển thị', () {
      expect(loiTuPhanHoi(0, null), LoiMua.mang);
      expect(loiTuPhanHoi(503, 'google-loi'), LoiMua.mang);
      expect(loiTuPhanHoi(422, 'token-sai'), LoiMua.tokenSai);
      expect(loiTuPhanHoi(403, 'token-qua-so-thiet-bi'), LoiMua.quaSoThietBi);
      expect(loiTuPhanHoi(403, 'khong-phai-ban-play'), LoiMua.khongPhaiBanPlay);
      expect(loiTuPhanHoi(403, 'che-do-nha-phat-trien'), LoiMua.mayChu);
    });
    test('chỉ lỗi tạm thời được thử lại', () {
      expect(thuLaiDuoc(LoiMua.mang), isTrue);
      expect(thuLaiDuoc(LoiMua.tokenSai), isFalse);
      expect(thuLaiDuoc(LoiMua.quaSoThietBi), isFalse);
    });
  });

  group('máy trạng thái Paywall', () {
    const g = GoiBan(sanPham: SanPham.proNam, giaHienThi: '99.000 đ');
    TrangThaiMua chay(List<SuKienMua> ds) =>
        ds.fold(const TrangThaiMua(), chuyenTrangThai);

    test('tải gói -> sẵn sàng; rỗng -> không khả dụng', () {
      expect(
        chay([
          const DaTaiGoi([g]),
        ]).giaiDoan,
        GiaiDoanMua.sanSang,
      );
      expect(chay([const DaTaiGoi([])]).giaiDoan, GiaiDoanMua.khongKhaDung);
      expect(
        chay([const CuaHangKhongKhaDung()]).giaiDoan,
        GiaiDoanMua.khongKhaDung,
      );
    });
    test('mua -> xác minh -> thành công', () {
      final s = chay([
        const DaTaiGoi([g]),
        const BatDauMua(),
        const BatDauXacMinh(),
        const XacMinhXong(QuyenLoi(pro: true, khongQuangCao: true)),
      ]);
      expect(s.giaiDoan, GiaiDoanMua.thanhCong);
      expect(s.loi, isNull);
    });
    test('đang mua thì khoá mua / khôi phục lần hai', () {
      final s = chay([
        const DaTaiGoi([g]),
        const BatDauMua(),
      ]);
      expect(s.ban, isTrue);
      expect(chuyenTrangThai(s, const BatDauKhoiPhuc()).dangKhoiPhuc, isFalse);
    });
    test('huỷ / lỗi mở Play -> về sẵn sàng', () {
      expect(
        chay([
          const DaTaiGoi([g]),
          const BatDauMua(),
          const NguoiDungHuy(),
        ]).giaiDoan,
        GiaiDoanMua.sanSang,
      );
      final l = chay([
        const DaTaiGoi([g]),
        const BatDauMua(),
        const MoMuaLoi(),
      ]);
      expect(l.loi, LoiMua.cuaHang);
      expect(l.ban, isFalse);
    });
    test('chờ thanh toán', () {
      expect(
        chay([
          const DaTaiGoi([g]),
          const BatDauMua(),
          const ChoThanhToan(),
        ]).giaiDoan,
        GiaiDoanMua.choThanhToan,
      );
    });
    test('khôi phục không thấy giao dịch -> lỗi riêng; bỏ lỗi', () {
      final s = chay([
        const DaTaiGoi([g]),
        const BatDauKhoiPhuc(),
        const KhoiPhucXong(thayGiaoDich: false),
      ]);
      expect(s.dangKhoiPhuc, isFalse);
      expect(s.loi, LoiMua.khongCoGiaoDich);
      expect(chuyenTrangThai(s, const BoLoi()).loi, isNull);
    });
    test('xác minh lỗi giữ gói, mở lại nút', () {
      final s = chay([
        const DaTaiGoi([g]),
        const BatDauMua(),
        const BatDauXacMinh(),
        const XacMinhLoi(LoiMua.quaSoThietBi),
      ]);
      expect(s.giaiDoan, GiaiDoanMua.sanSang);
      expect(s.loi, LoiMua.quaSoThietBi);
      expect(s.goi, [g]);
    });
    test('mở lại Paywall khi đã có gói không về chỗ chờ', () {
      final s = chay([
        const DaTaiGoi([g]),
        const BatDauTai(),
      ]);
      expect(s.giaiDoan, GiaiDoanMua.sanSang);
      expect(chay([const BatDauTai()]).giaiDoan, GiaiDoanMua.dangTai);
    });
  });
}
