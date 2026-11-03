import 'package:flutter_test/flutter_test.dart';
import 'package:security_sdk/security_sdk.dart';

void main() {
  test('tuMap: thiếu / sai kiểu -> false; bat khi bất kỳ công tắc nào bật', () {
    expect(TrangThaiPhatTrien.tuMap(null), TrangThaiPhatTrien.sach);
    expect(TrangThaiPhatTrien.tuMap(const {'devMode': 'true'}).bat, isFalse);
    final t = TrangThaiPhatTrien.tuMap(const {'adb': true});
    expect(t.bat, isTrue);
    expect(t.thamSo, '1');
    expect(TrangThaiPhatTrien.sach.thamSo, '0');
    expect(t, const TrangThaiPhatTrien(adb: true));
    expect(t.hashCode, const TrangThaiPhatTrien(adb: true).hashCode);
  });

  test('canChanPhatTrien: chỉ bản prod, không miễn trừ, kill-switch từ xa', () {
    const bat = TrangThaiPhatTrien(devMode: true);
    bool chan({
      TrangThaiPhatTrien cb = bat,
      bool prod = true,
      bool mayChu = false,
      Set<String> tat = const {},
    }) => canChanPhatTrien(
      cucBo: cb,
      banProd: prod,
      mayChuBao: mayChu,
      tatTuXa: tat,
    );
    expect(chan(), isTrue);
    expect(chan(prod: false), isFalse);
    expect(chan(cb: TrangThaiPhatTrien.sach), isFalse);
    expect(chan(cb: TrangThaiPhatTrien.sach, mayChu: true), isTrue);
    expect(chan(tat: {khoaTatChanPhatTrien}), isFalse);
    expect(chan(tat: {'banDo'}), isTrue);
  });
}
