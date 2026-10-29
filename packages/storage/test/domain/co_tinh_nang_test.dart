import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

void main() {
  test('mặc định: mọi cờ bật trừ quảng cáo', () {
    final co = tinhCo();
    expect(co[CoTinhNang.quangCao], isFalse);
    expect(
      CoTinhNang.values
          .where((c) => c != CoTinhNang.quangCao)
          .every((c) => co[c]!),
      isTrue,
    );
  });

  test('chế độ an toàn tắt hết kể cả ghi đè bật', () {
    final co = tinhCo(cucBo: {CoTinhNang.quangCao: true}, anToan: true);
    expect(co.values, everyElement(isFalse));
  });

  test('kill-switch từ xa thắng ghi đè cục bộ', () {
    final co = tinhCo(
      cucBo: {CoTinhNang.banDo: true, CoTinhNang.quangCao: true},
      tatTuXa: {CoTinhNang.banDo},
    );
    expect(co[CoTinhNang.banDo], isFalse);
    expect(co[CoTinhNang.quangCao], isTrue);
  });

  test('ghi đè cục bộ tắt được', () {
    expect(tinhCo(cucBo: {CoTinhNang.ar: false})[CoTinhNang.ar], isFalse);
  });

  test('JSON khứ hồi, bỏ khoá / kiểu lạ', () {
    final co = {CoTinhNang.ar: false, CoTinhNang.dongBo: true};
    expect(coTuJson(coRaJson(co)), co);
    expect(coTuJson({'ar': 'false', 'khongCo': true, 'banDo': false}), {
      CoTinhNang.banDo: false,
    });
  });

  test('tên cờ từ xa (kebab) -> cờ; tên lạ bỏ qua', () {
    expect(coTuTenTuXa(['ban-do', 'chia-se', 'dong-bo', 'camera', 'banDo']), {
      CoTinhNang.banDo,
      CoTinhNang.chiaSe,
      CoTinhNang.dongBo,
    });
    expect(coTuTenTuXa(['ar', 'quang-cao']), {
      CoTinhNang.ar,
      CoTinhNang.quangCao,
    });
    expect(coTuTenTuXa(const []), isEmpty);
  });
}
