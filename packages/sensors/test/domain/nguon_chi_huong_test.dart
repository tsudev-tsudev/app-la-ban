import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors/sensors.dart';

import '../mo_phong.dart';

/// Vị trí Mặt Trời theo công thức của NOAA Solar Calculator (bảng tính
/// NOAA_Solar_Calculations_day.xls - Jean Meeus rút gọn), viết độc lập với
/// `viTriMatTroi` để đối chiếu. Độ cao CHƯA khúc xạ.
({double phuongVi, double doCao}) noaa(DateTime t, double viDo, double kinhDo) {
  const r = math.pi / 180;
  final jd = t.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;
  final jc = (jd - 2451545) / 36525;
  final l0 = (280.46646 + jc * (36000.76983 + jc * 0.0003032)) % 360;
  final m = 357.52911 + jc * (35999.05029 - 0.0001537 * jc);
  final e = 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc);
  final c =
      math.sin(m * r) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
      math.sin(2 * m * r) * (0.019993 - 0.000101 * jc) +
      math.sin(3 * m * r) * 0.000289;
  final trueLong = l0 + c;
  final appLong =
      trueLong - 0.00569 - 0.00478 * math.sin((125.04 - 1934.136 * jc) * r);
  final eps0 =
      23 +
      (26 + (21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813))) / 60) /
          60;
  final eps = eps0 + 0.00256 * math.cos((125.04 - 1934.136 * jc) * r);
  final dec = math.asin(math.sin(eps * r) * math.sin(appLong * r)) / r;
  final y = math.pow(math.tan(eps / 2 * r), 2).toDouble();
  final eqTime =
      4 /
      r *
      (y * math.sin(2 * l0 * r) -
          2 * e * math.sin(m * r) +
          4 * e * y * math.sin(m * r) * math.cos(2 * l0 * r) -
          0.5 * y * y * math.sin(4 * l0 * r) -
          1.25 * e * e * math.sin(2 * m * r));
  final phutUtc =
      t.toUtc().hour * 60 + t.toUtc().minute + t.toUtc().second / 60;
  final tst = ((phutUtc + eqTime + 4 * kinhDo) % 1440 + 1440) % 1440;
  final ha = tst / 4 < 0 ? tst / 4 + 180 : tst / 4 - 180;
  final cosZ =
      math.sin(viDo * r) * math.sin(dec * r) +
      math.cos(viDo * r) * math.cos(dec * r) * math.cos(ha * r);
  final zen = math.acos(cosZ.clamp(-1.0, 1.0)) / r;
  final cosAz =
      ((math.sin(viDo * r) * math.cos(zen * r)) - math.sin(dec * r)) /
      (math.cos(viDo * r) * math.sin(zen * r));
  final az0 = math.acos(cosAz.clamp(-1.0, 1.0)) / r;
  final az = ha > 0 ? (az0 + 180) % 360 : (540 - az0) % 360;
  return (phuongVi: az, doCao: 90 - zen);
}

ChuyenDongGps gps(
  double vi,
  double kinh,
  int giay, {
  double? tocDo = 1.5,
  double? huong = 90,
  double? saiSoTocDo,
  double? saiSoHuong = 8,
}) => (
  viDo: vi,
  kinhDo: kinh,
  tocDo: tocDo,
  huongDi: huong,
  saiSoTocDo: saiSoTocDo,
  saiSoHuongDi: saiSoHuong,
  luc: DateTime.utc(2026, 11, 4, 8).add(Duration(seconds: giay)),
);

void main() {
  group('Mặt Trời so công thức NOAA (Q59: sai số <= 0,5°)', () {
    final noi = [
      (21.0285, 105.8542), // Hà Nội
      (10.7769, 106.7009), // TP HCM
      (-33.86, 151.21), // Sydney
      (51.48, 0.0), // Greenwich
      (64.15, -21.94), // Reykjavik
    ];
    for (final (vi, kinh) in noi) {
      test('$vi, $kinh - cả năm 2026, mỗi 7 ngày x 3 giờ', () {
        var dem = 0;
        for (var ngay = 0; ngay < 365; ngay += 7) {
          for (var gio = 0; gio < 24; gio += 3) {
            final t = DateTime.utc(2026).add(Duration(days: ngay, hours: gio));
            final ref = noaa(t, vi, kinh);
            if (ref.doCao < 3) continue; // dùng được để neo từ 3° trở lên
            final s = viTriMatTroi(t, vi, kinh);
            // viTriMatTroi có khúc xạ; NOAA ở đây chưa -> trừ ra để so.
            expect(
              s.doCao - khucXa(ref.doCao),
              closeTo(ref.doCao, 0.5),
              reason: '$t',
            );
            if (ref.doCao < 85) {
              expect(saiSo(s.phuongVi, ref.phuongVi), lessThan(0.5));
            }
            dem++;
          }
        }
        expect(dem, greaterThan(100));
      });
    }
  });

  group('năng lực thiết bị', () {
    const du = (
      xoayVector: true,
      xoayGame: true,
      tu: true,
      giaToc: true,
      conQuay: true,
      apSuat: false,
    );
    test('đủ cảm biến: từ kế đứng đầu', () {
      final n = nangLucTu(du, gps: true, camera: true);
      expect(nguonKhaDung(n).first, NguonChiHuong.tuKe);
      expect(giuHuongDuoc(n), isTrue);
      expect(mayYeu(n, soNhan: 8), isFalse);
    });

    test('máy rẻ không từ kế, không con quay: GPS, thiên thể, thủ công', () {
      final n = nangLucTu(
        (
          xoayVector: false,
          xoayGame: false,
          tu: false,
          giaToc: true,
          conQuay: false,
          apSuat: false,
        ),
        gps: true,
        camera: false,
      );
      expect(nguonKhaDung(n), [
        NguonChiHuong.gps,
        NguonChiHuong.matTroi,
        NguonChiHuong.matTrang,
        NguonChiHuong.thuCong,
      ]);
      expect(giuHuongDuoc(n), isFalse);
      expect(mayYeu(n, soNhan: 8), isTrue);
    });
  });

  group('hướng GPS', () {
    test('đứng yên / chậm: không tin', () {
      final g = TheoDoiHuongGps();
      expect(g.nap(gps(21, 105, 0, tocDo: 0.4)), isNull);
      expect(g.nap(gps(21, 105, 1, tocDo: null)), isNull);
    });

    test('đi đều về phía đông: tin sau khi vệt đủ dài', () {
      final g = TheoDoiHuongGps();
      HuongUocLuong? kq;
      // 1,5 m/s về phía đông ~ 1,5 m mỗi giây.
      for (var i = 0; i < 12; i++) {
        kq = g.nap(gps(21, 105 + i * 1.5 / 103900, i));
        if (i < 3) expect(kq, isNull, reason: 'vệt mới ${g.doDaiVetM} m');
      }
      expect(kq, isNotNull);
      expect(kq!.phuongVi, 90);
      expect(kq.bacThuc, isTrue);
      expect(kq.saiSoDo, 8);
    });

    test('đổi hướng gắt hoặc đứng lại: vệt mới', () {
      final g = TheoDoiHuongGps();
      for (var i = 0; i < 12; i++) {
        g.nap(gps(21, 105 + i * 1.5 / 103900, i));
      }
      expect(g.nap(gps(21, 105.0002, 12, huong: 200)), isNull);
      expect(g.doDaiVetM, 0);
    });

    test('không có sai số hướng: suy từ sai số tốc độ', () {
      final g = TheoDoiHuongGps();
      HuongUocLuong? kq;
      for (var i = 0; i < 12; i++) {
        kq = g.nap(
          gps(
            21,
            105 + i * 2 / 103900,
            i,
            tocDo: 2,
            saiSoHuong: null,
            saiSoTocDo: 0.5,
          ),
        );
      }
      // atan(0,5 / 2) ~ 14°.
      expect(kq!.saiSoDo, closeTo(14.04, 0.1));
    });
  });

  group('thiên thể', () {
    test('ngắm thẳng = phương vị; theo bóng = ngược lại', () {
      const tt = (phuongVi: 135.0, doCao: 40.0);
      expect(
        huongTuThienThe(
          tt,
          nguon: NguonChiHuong.matTrang,
          theoBong: false,
        )!.phuongVi,
        135,
      );
      expect(
        huongTuThienThe(
          tt,
          nguon: NguonChiHuong.matTroi,
          theoBong: true,
        )!.phuongVi,
        315,
      );
    });

    test(
      'quá thấp / bóng gần thiên đỉnh: không dùng; bóng ngắn sai số lớn',
      () {
        expect(
          huongTuThienThe(
            (phuongVi: 90, doCao: 1),
            nguon: NguonChiHuong.matTroi,
            theoBong: true,
          ),
          isNull,
        );
        expect(
          huongTuThienThe(
            (phuongVi: 90, doCao: 85),
            nguon: NguonChiHuong.matTroi,
            theoBong: true,
          ),
          isNull,
        );
        expect(
          huongTuThienThe(
            (phuongVi: 90, doCao: 76),
            nguon: NguonChiHuong.matTroi,
            theoBong: true,
          )!.saiSoDo,
          13,
        );
      },
    );
  });

  group('neo + con quay', () {
    const goc = (
      phuongVi: 300.0,
      bacThuc: true,
      nguon: NguonChiHuong.matTroi,
      saiSoDo: 5.0,
      theoConQuay: false,
    );
    test('xoay máy: hướng = tương đối + lệch', () {
      final n = NeoHuong.tu(goc, phuongViTuongDoi: 10, tNs: 0);
      final u = n.uocLuong(40, 0);
      expect(u.phuongVi, 330);
      expect(u.theoConQuay, isTrue);
      expect(u.nguon, NguonChiHuong.matTroi);
    });

    test('trôi: sai số tăng 1°/phút, quá 15° thì nhắc neo lại', () {
      final n = NeoHuong.tu(goc, phuongViTuongDoi: 0, tNs: 0);
      const phut = 60000000000;
      expect(n.saiSoLuc(5 * phut), closeTo(10, 1e-9));
      expect(n.canNeoLai(9 * phut), isFalse);
      expect(n.canNeoLai(11 * phut), isTrue);
    });

    test('máy không giữ được hướng: neo tĩnh, sai số không đổi', () {
      final n = NeoHuong.tu(goc, phuongViTuongDoi: 0, tNs: 0, tinh: true);
      expect(n.uocLuong(123, 600000000000).phuongVi, 300);
      expect(n.canNeoLai(600000000000), isFalse);
    });

    test('hướng tương đối từ con quay + gia tốc (không từ kế) theo kịp '
        'quay 90°', () {
      final bo = BoHuongTuongDoi();
      final mau = moPhong(
        (t) => tuGoc(t < 1 ? 0 : math.min(90, (t - 1) * 45), 0, 0),
        thoiGian: 4,
        coXoayVector: false,
      ).where((m) => m.loai != LoaiMau.tu);
      double? dau;
      double? cuoi;
      for (final m in mau) {
        final r = bo.nap(m);
        if (r == null) continue;
        dau ??= r.phuongVi;
        cuoi = r.phuongVi;
      }
      expect(saiSo(cuoi! - dau!, 90), lessThan(3));
    });

    test('ưu tiên game rotation vector khi có', () {
      final bo = BoHuongTuongDoi();
      final q = tuGoc(77, 0, 0);
      final r = bo.nap(
        MauCamBien(LoaiMau.xoayGame, 5, x: q.x, y: q.y, z: q.z, w: q.w),
      );
      expect(saiSo(r!.phuongVi, 77), lessThan(1e-6));
      expect(bo.nap(const MauCamBien(LoaiMau.conQuay, 6)), isNull);
    });
  });

  group('chọn nguồn', () {
    HuongUocLuong u(NguonChiHuong n, double s) =>
        (phuongVi: 10, bacThuc: true, nguon: n, saiSoDo: s, theoConQuay: false);
    test('từ kế > GPS > neo theo thứ tự', () {
      expect(
        chonHuong(
          tuKe: u(NguonChiHuong.tuKe, 8),
          gps: u(NguonChiHuong.gps, 8),
          neo: u(NguonChiHuong.matTroi, 5),
        )!.nguon,
        NguonChiHuong.tuKe,
      );
      expect(
        chonHuong(
          gps: u(NguonChiHuong.gps, 10),
          neo: u(NguonChiHuong.matTroi, 6),
        )!.nguon,
        NguonChiHuong.gps,
      );
      expect(chonHuong(), isNull);
    });

    test('từ kế nhiễu nặng, đang đi có GPS tốt: chọn GPS', () {
      expect(
        chonHuong(
          tuKe: u(NguonChiHuong.tuKe, saiSoTuKe(MucTinCay.thap, nhieuTu: true)),
          gps: u(NguonChiHuong.gps, 8),
        )!.nguon,
        NguonChiHuong.gps,
      );
    });
  });
}
