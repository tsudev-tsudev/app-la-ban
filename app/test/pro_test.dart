import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/flavor.dart';
import 'package:la_ban/src/pro.dart';
import 'package:quyen_loi/quyen_loi.dart';
import 'package:security_sdk/security_sdk.dart';

PhanHoiKy _r(int status, Map<String, Object?>? j) =>
    (status: status, duLieu: j, gioMayChu: null);

void main() {
  group('hienMucPro (Q61)', () {
    bool hien(
      Flavor f, {
      Set<String> tat = const {},
      bool coPro = false,
      bool coDichVu = true,
    }) => hienMucPro(flavor: f, tat: tat, coPro: coPro, coDichVu: coDichVu);

    test('dev / staging mở bán; prod chưa mở tới R4', () {
      expect(hien(Flavor.staging), isTrue);
      expect(hien(Flavor.dev), isTrue);
      expect(hien(Flavor.prod), moBanProTrongProd);
    });
    test('kill-switch mua-pro ẩn mục khi chưa có Pro', () {
      expect(hien(Flavor.staging, tat: {tatMuaPro}), isFalse);
    });
    test('đã có Pro (kể cả prod / bị tắt bán) -> luôn hiện', () {
      expect(hien(Flavor.prod, tat: {tatMuaPro}, coPro: true), isTrue);
    });
    test('không có dịch vụ (iOS / chế độ an toàn) -> ẩn', () {
      expect(hien(Flavor.staging, coPro: true, coDichVu: false), isFalse);
    });
  });

  test('liên kết Gói thuê bao của Play khớp danh sách cho phép native', () {
    expect(
      lienKetQuanLyGoi('com.tsudev.laban').toString(),
      'https://play.google.com/store/account/subscriptions'
      '?package=com.tsudev.laban',
    );
  });

  group('ketQuaXacMinh', () {
    test('200 + quyenLoi -> cấp', () {
      final k = ketQuaXacMinh(
        Ok(
          _r(200, {
            'trangThai': 'active',
            'quyenLoi': {'pro': true, 'khongQuangCao': true, 'hetHan': 9},
          }),
        ),
      );
      expect(
        k.quyenLoi,
        const QuyenLoi(pro: true, khongQuangCao: true, hetHan: 9),
      );
      expect(k.loi, isNull);
    });
    test('mã lỗi Worker', () {
      expect(
        ketQuaXacMinh(Ok(_r(403, {'code': 'token-qua-so-thiet-bi'}))).loi,
        LoiMua.quaSoThietBi,
      );
      expect(
        ketQuaXacMinh(Ok(_r(422, {'code': 'token-sai'}))).loi,
        LoiMua.tokenSai,
      );
      expect(ketQuaXacMinh(Ok(_r(503, null))).loi, LoiMua.mang);
    });
    test('mất mạng / phản hồi sai dạng', () {
      expect(ketQuaXacMinh(const Err(Failure('mang'))).loi, LoiMua.mang);
      expect(ketQuaXacMinh(Ok(_r(200, {'x': 1}))).loi, LoiMua.mayChu);
    });
  });
}
