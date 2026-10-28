import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('fold đi đúng nhánh', () {
    const Result<int> ok = Ok(2);
    const Result<int> err = Err(Failure('x.y'));
    expect(ok.fold((v) => v * 2, (_) => -1), 4);
    expect(err.fold((v) => v, (f) => f.code), 'x.y');
  });
}
