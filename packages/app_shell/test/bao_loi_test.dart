import 'dart:io';

import 'package:app_shell/src/bao_loi.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_sdk/security_sdk.dart';
import 'package:storage/storage.dart';

void main() {
  late Directory tam;
  late HangBaoLoi hang;

  setUp(() {
    tam = Directory.systemTemp.createTempSync('bao-loi');
    hang = HangBaoLoi(TepJson.mo('${tam.path}/bao_cao_loi.json'));
  });
  tearDown(() => tam.deleteSync(recursive: true));

  BaoCaoLoi bc(int i) => BaoCaoLoi(
    loai: 'dart',
    kieu: 'E$i',
    thongDiep: 'm',
    nganXep: '#0',
    phienBan: '0.1.0',
    luc: i,
  );

  test('hàng đợi sống qua lần mở lại tệp', () async {
    await hang.them(bc(1));
    await hang.them(bc(2));
    final lai = HangBaoLoi(TepJson.mo('${tam.path}/bao_cao_loi.json'));
    expect(lai.doc().map((b) => b.kieu), ['E1', 'E2']);
  });

  test(
    'gửi lô <= 10: 202 bỏ khỏi hàng, lỗi mạng / 503 giữ lại, 422 bỏ',
    () async {
      for (var i = 0; i < 12; i++) {
        await hang.them(bc(i));
      }
      Map<String, Object?>? daGui;
      Future<Result<PhanHoiKy>> tra(int st, Map<String, Object?> than) async {
        daGui = than;
        return Ok((status: st, duLieu: null, gioMayChu: null));
      }

      await guiBaoLoi(hang, (t) => tra(503, t));
      expect(hang.doc(), hasLength(12));
      expect((daGui!['suCo']! as List).length, loGuiToiDa);
      await guiBaoLoi(hang, (_) async => const Err(Failure('mang')));
      expect(hang.doc(), hasLength(12));
      await guiBaoLoi(hang, (t) => tra(202, t));
      expect(hang.doc().map((b) => b.kieu), ['E10', 'E11']);
      await guiBaoLoi(hang, (t) => tra(422, t));
      expect(hang.doc(), isEmpty);
    },
  );

  test('xoaHet khi rút đồng ý', () async {
    await hang.them(bc(1));
    await hang.xoaHet();
    expect(hang.doc(), isEmpty);
  });
}
