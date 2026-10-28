import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

void main() {
  group('batDauKhoiDong', () {
    test('3 lần chưa ổn định -> lần 4 vào an toàn và ghim phiên bản', () {
      var tt = const TrangThaiKhoiDong();
      for (var i = 1; i <= 3; i++) {
        final kd = batDauKhoiDong(tt, phienBan: '1.0.0');
        expect(kd.anToan, isNull, reason: 'lần $i');
        tt = kd.trangThai;
      }
      final kd = batDauKhoiDong(tt, phienBan: '1.0.0');
      expect(kd.anToan, LyDoAnToan.crashLienTiep);
      expect(kd.trangThai.anToanChoPhienBan, '1.0.0');
      expect(kd.trangThai.soLanChuaOnDinh, 4);
    });

    test('ổn định xoá bộ đếm nhưng giữ ghim; ghim còn hiệu lực', () {
      const ghim = TrangThaiKhoiDong(
        soLanChuaOnDinh: 4,
        anToanChoPhienBan: '1.0.0',
        lyDo: LyDoAnToan.crashLienTiep,
      );
      final od = daOnDinh(ghim);
      expect(od.soLanChuaOnDinh, 0);
      expect(od.anToanChoPhienBan, '1.0.0');
      final kd = batDauKhoiDong(od, phienBan: '1.0.0');
      expect(kd.anToan, LyDoAnToan.crashLienTiep);
    });

    test('ghim không có lý do -> mặc định crashLienTiep', () {
      final kd = batDauKhoiDong(
        const TrangThaiKhoiDong(anToanChoPhienBan: '1.0.0'),
        phienBan: '1.0.0',
      );
      expect(kd.anToan, LyDoAnToan.crashLienTiep);
    });

    test('lên bản mới -> bỏ ghim, đếm lại từ 1', () {
      const ghim = TrangThaiKhoiDong(
        soLanChuaOnDinh: 9,
        anToanChoPhienBan: '1.0.0',
        lyDo: LyDoAnToan.crashLienTiep,
      );
      final kd = batDauKhoiDong(ghim, phienBan: '1.0.1');
      expect(kd.anToan, isNull);
      expect(kd.trangThai, const TrangThaiKhoiDong(soLanChuaOnDinh: 1));
    });

    test('ổn định giữa chừng -> không bao giờ tới ngưỡng', () {
      var tt = const TrangThaiKhoiDong();
      for (var i = 0; i < 10; i++) {
        final kd = batDauKhoiDong(tt, phienBan: '1');
        expect(kd.anToan, isNull);
        tt = daOnDinh(kd.trangThai);
      }
    });

    test('thoatAnToan xoá hết', () {
      expect(
        thoatAnToan(const TrangThaiKhoiDong(soLanChuaOnDinh: 2)),
        const TrangThaiKhoiDong(),
      );
    });
  });

  group('TrangThaiKhoiDong JSON', () {
    test('khứ hồi', () {
      const tt = TrangThaiKhoiDong(
        soLanChuaOnDinh: 2,
        anToanChoPhienBan: '1.2.3',
        lyDo: LyDoAnToan.csdlMoiHon,
      );
      expect(TrangThaiKhoiDong.tuJson(tt.toJson()), tt);
      expect(tt.hashCode, TrangThaiKhoiDong.tuJson(tt.toJson()).hashCode);
      expect(tt.toString(), contains('csdlMoiHon'));
    });

    test('giá trị lạ -> mặc định, không ném', () {
      expect(
        TrangThaiKhoiDong.tuJson(const {
          'soLanChuaOnDinh': -5,
          'anToanChoPhienBan': '',
          'lyDo': 'khongCo',
        }),
        const TrangThaiKhoiDong(),
      );
      expect(
        TrangThaiKhoiDong.tuJson(const {'soLanChuaOnDinh': '3'}),
        const TrangThaiKhoiDong(),
      );
      expect(const TrangThaiKhoiDong().toJson(), {'soLanChuaOnDinh': 0});
    });
  });
}
