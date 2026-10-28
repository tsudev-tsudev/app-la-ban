import 'package:flutter_test/flutter_test.dart';
import 'package:la_ban/src/app.dart';
import 'package:la_ban/src/flavor.dart';

void main() {
  testWidgets('hiện tên app theo flavor', (tester) async {
    await tester.pumpWidget(const LaBanApp(flavor: Flavor.dev));
    expect(find.text('La bàn DEV'), findsOneWidget);
  });
}
