import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_feature/settings_feature.dart';

void main() {
  final luc = DateTime.utc(2026, 10, 30, 8, 15);

  group('DongYXuLy', () {
    test('JSON khứ hồi, == / hashCode / toString', () {
      final d = DongYXuLy(ban: 1, trucTuyen: true, luc: luc);
      final lai = DongYXuLy.tuJson(jsonDecode(jsonEncode(d.toJson())));
      expect(lai, d);
      expect(lai.hashCode, d.hashCode);
      expect(d.toJson()['luc'], '2026-10-30T08:15:00.000Z');
      expect(d.toString(), contains('trucTuyen: true'));
      expect(d, isNot(DongYXuLy(ban: 1, trucTuyen: false, luc: luc)));
    });

    test('so thời điểm theo khoảnh khắc (giờ máy hay UTC như nhau)', () {
      expect(
        DongYXuLy(ban: 1, trucTuyen: true, luc: luc.toLocal()),
        DongYXuLy(ban: 1, trucTuyen: true, luc: luc),
      );
    });

    test('JSON hỏng / thiếu trường -> null (coi như chưa trả lời)', () {
      for (final j in <Object?>[
        null,
        'x',
        <String, Object?>{},
        {'ban': '1', 'trucTuyen': true, 'luc': '2026-10-30T08:15:00Z'},
        {'ban': 1, 'trucTuyen': 'co', 'luc': '2026-10-30T08:15:00Z'},
        {'ban': 1, 'trucTuyen': true, 'luc': 'hom qua'},
        {'ban': 1, 'trucTuyen': true, 'luc': 5},
      ]) {
        expect(DongYXuLy.tuJson(j), isNull, reason: '$j');
      }
    });

    test('hỏi lại khi chưa trả lời hoặc trả lời bản thông báo cũ', () {
      expect(canHoiDongY(null), isTrue);
      expect(
        canHoiDongY(
          DongYXuLy(ban: banThongBaoDuLieu - 1, trucTuyen: true, luc: luc),
        ),
        isTrue,
      );
      expect(
        canHoiDongY(
          DongYXuLy(ban: banThongBaoDuLieu, trucTuyen: false, luc: luc),
        ),
        isFalse,
      );
    });

    test('chỉ trực tuyến khi đồng ý đúng bản hiện hành', () {
      expect(choPhepTrucTuyen(null), isFalse);
      expect(
        choPhepTrucTuyen(
          DongYXuLy(ban: banThongBaoDuLieu, trucTuyen: true, luc: luc),
        ),
        isTrue,
      );
      expect(
        choPhepTrucTuyen(
          DongYXuLy(ban: banThongBaoDuLieu, trucTuyen: false, luc: luc),
        ),
        isFalse,
      );
      expect(
        choPhepTrucTuyen(
          DongYXuLy(ban: banThongBaoDuLieu - 1, trucTuyen: true, luc: luc),
        ),
        isFalse,
      );
    });
  });

  group('CaiDat + đồng ý', () {
    test('bản cũ chưa có khoá dongY -> phải qua màn giới thiệu', () {
      final c = CaiDat.tuJson(const {'daXemGioiThieu': true});
      expect(c.dongY, isNull);
      expect(c.canGioiThieu, isTrue);
      expect(c.trucTuyen, isFalse);
      expect(c.toJson().containsKey('dongY'), isFalse);
    });

    test('JSON khứ hồi giữ lựa chọn', () {
      final c = CaiDat(
        daXemGioiThieu: true,
        dongY: DongYXuLy(ban: banThongBaoDuLieu, trucTuyen: true, luc: luc),
      );
      final lai = CaiDat.tuJson(
        jsonDecode(jsonEncode(c.toJson())) as Map<String, Object?>,
      );
      expect(lai, c);
      expect(lai.canGioiThieu, isFalse);
      expect(lai.trucTuyen, isTrue);
      expect(lai.toString(), contains('dongY: DongYXuLy'));
    });

    test('Notifier.datDongY ghi bản hiện hành, xong giới thiệu', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(caiDatProvider.notifier).datDongY(trucTuyen: false, luc: luc);
      final s = c.read(caiDatProvider);
      expect(s.daXemGioiThieu, isTrue);
      expect(
        s.dongY,
        DongYXuLy(ban: banThongBaoDuLieu, trucTuyen: false, luc: luc),
      );
      expect(s.canGioiThieu, isFalse);
      expect(s.trucTuyen, isFalse);
      c.read(caiDatProvider.notifier).datDongY(trucTuyen: true);
      expect(c.read(caiDatProvider).trucTuyen, isTrue);
      expect(c.read(khoCaiDatProvider).doc().trucTuyen, isTrue);
    });
  });

  group('xuất dữ liệu', () {
    test('gói đủ trường, bỏ mã thiết bị khi chưa đăng ký', () {
      Map<String, Object?> goi({String? ma}) => goiDuLieuXuat(
        phienBanApp: '0.1.0-beta.10',
        luc: luc,
        caiDat: {'cheDo': 'toi'},
        tuyChonLaBan: {'bacThuc': true},
        viTri: {'viDo': 21.0},
        diem: [
          {'id': 'a'},
        ],
        maThietBi: ma,
      );
      final g = goi(ma: 'dv_1');
      expect(g['dinhDang'], dinhDangXuat);
      expect(g['phienBanDinhDang'], phienBanDinhDangXuat);
      expect(g['taoLuc'], '2026-10-30T08:15:00.000Z');
      expect(g['phienBanApp'], '0.1.0-beta.10');
      expect(g['maThietBi'], 'dv_1');
      expect(g['caiDat'], {'cheDo': 'toi'});
      expect(g['tuyChonLaBan'], {'bacThuc': true});
      expect(g['viTri'], {'viDo': 21.0});
      expect(g['diem'], [
        {'id': 'a'},
      ]);
      expect(goi().containsKey('maThietBi'), isFalse);
      // Mã hoá JSON được (không đối tượng lạ).
      expect(() => jsonEncode(g), returnsNormally);
    });

    test('tên tệp theo ngày, có số 0 đầu', () {
      expect(tenTepXuat(DateTime(2026, 3, 5)), 'la-ban-du-lieu-20260305.json');
      expect(
        tenTepXuat(DateTime(2026, 12, 31)),
        'la-ban-du-lieu-20261231.json',
      );
    });

    test('thư yêu cầu xoá: đúng hộp thư, mã hoá %20 + xuống dòng', () {
      final u = thuYeuCauXoa(
        chuDe: 'Yêu cầu xoá',
        noiDung: 'Mã: dv_1\nXoá giúp',
      );
      expect(u.scheme, 'mailto');
      expect(u.path, thuRiengTu);
      final s = u.toString();
      expect(s, startsWith('mailto:privacy@tsudev.com?subject='));
      expect(s, isNot(contains('+')));
      expect(s, contains('%0A'));
      expect(u.queryParameters['subject'], 'Yêu cầu xoá');
      expect(u.queryParameters['body'], 'Mã: dv_1\nXoá giúp');
    });

    test('chính sách theo ngôn ngữ', () {
      expect(
        urlChinhSach('vi').toString(),
        'https://compass.tsudev.com/quyen-rieng-tu/',
      );
      expect(
        urlChinhSach('en').toString(),
        'https://compass.tsudev.com/en/privacy/',
      );
      expect(urlChinhSach('en_XA').path, '/en/privacy/');
    });
  });
}
