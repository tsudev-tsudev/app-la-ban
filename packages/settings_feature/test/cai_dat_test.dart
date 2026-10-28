import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settings_feature/settings_feature.dart';

void main() {
  test('CaiDat mặc định theo hệ thống, chưa xem giới thiệu', () {
    const c = CaiDat();
    expect(c.ngonNgu, LuaChonNgonNgu.heThong);
    expect(c.cheDo, CheDoGiaoDien.heThong);
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
      ..datCheDo(CheDoGiaoDien.toi)
      ..xongGioiThieu();
    expect(
      c.read(caiDatProvider),
      const CaiDat(
        ngonNgu: LuaChonNgonNgu.vi,
        cheDo: CheDoGiaoDien.toi,
        daXemGioiThieu: true,
      ),
    );
  });
}
