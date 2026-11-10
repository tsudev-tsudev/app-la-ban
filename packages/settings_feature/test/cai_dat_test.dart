import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_feature/settings_feature.dart';
import 'package:storage/storage.dart';

void main() {
  test('CaiDat mặc định: ngôn ngữ hệ thống, giao diện Tối (Q68)', () {
    const c = CaiDat();
    expect(c.ngonNgu, LuaChonNgonNgu.heThong);
    expect(c.cheDo, CheDoGiaoDien.toi);
    expect(c.daXemGioiThieu, isFalse);
  });

  test('copyWith / == / hashCode / toString', () {
    const a = CaiDat();
    final b = a.copyWith(ngonNgu: LuaChonNgonNgu.en);
    expect(b, isNot(a));
    expect(b.copyWith(ngonNgu: LuaChonNgonNgu.heThong), a);
    expect(a.copyWith().hashCode, a.hashCode);
    expect(b.toString(), contains('ngonNgu: en'));
  });

  test('mã ngôn ngữ của từng lựa chọn', () {
    expect(LuaChonNgonNgu.heThong.maNgonNgu, isNull);
    expect(LuaChonNgonNgu.vi.maNgonNgu, 'vi');
    expect(LuaChonNgonNgu.en.maNgonNgu, 'en');
  });

  test('Notifier đổi đúng trường', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(caiDatProvider.notifier)
      ..datNgonNgu(LuaChonNgonNgu.vi)
      ..datCheDo(CheDoGiaoDien.sang)
      ..xongGioiThieu();
    expect(
      c.read(caiDatProvider),
      const CaiDat(
        ngonNgu: LuaChonNgonNgu.vi,
        cheDo: CheDoGiaoDien.sang,
        daXemGioiThieu: true,
      ),
    );
  });

  test('JSON khứ hồi; giá trị lạ -> mặc định từng trường', () {
    const c = CaiDat(
      ngonNgu: LuaChonNgonNgu.en,
      cheDo: CheDoGiaoDien.sang,
      daXemGioiThieu: true,
    );
    expect(CaiDat.tuJson(c.toJson()), c);
    expect(CaiDat.tuJson(const {}), const CaiDat());
    expect(
      CaiDat.tuJson(const {
        'ngonNgu': 'fr',
        'cheDo': 'heThong',
        'daXemGioiThieu': 1,
      }),
      const CaiDat(cheDo: CheDoGiaoDien.heThong),
    );
  });

  test('Notifier đọc kho lúc dựng và ghi mỗi lần đổi', () async {
    final tm = Directory.systemTemp.createTempSync('cai_dat');
    addTearDown(() => tm.deleteSync(recursive: true));
    final duong = '${tm.path}/cai_dat.json';
    TepJson.mo(duong).ghiDongBo(const {'cheDo': 'sang'});
    final kho = KhoCaiDatTep(TepJson.mo(duong));
    final c = ProviderContainer(
      overrides: [khoCaiDatProvider.overrideWithValue(kho)],
    );
    addTearDown(c.dispose);
    expect(c.read(caiDatProvider).cheDo, CheDoGiaoDien.sang);
    c.read(caiDatProvider.notifier)
      ..datNgonNgu(LuaChonNgonNgu.en)
      ..xongGioiThieu();
    await kho.ghi(c.read(caiDatProvider));
    expect(
      CaiDat.tuJson(TepJson.mo(duong).duLieu),
      const CaiDat(
        ngonNgu: LuaChonNgonNgu.en,
        cheDo: CheDoGiaoDien.sang,
        daXemGioiThieu: true,
      ),
    );
  });

  test('KhoCaiDatBoNho giữ giá trị', () async {
    final k = KhoCaiDatBoNho();
    expect(k.doc(), const CaiDat());
    await k.ghi(const CaiDat(daXemGioiThieu: true));
    expect(k.doc().daXemGioiThieu, isTrue);
  });
}
