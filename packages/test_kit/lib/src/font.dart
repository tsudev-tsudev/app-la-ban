import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';

const _trongSo = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
var _daNap = false;

/// Nạp font Be Vietnam Pro thật (thay Ahem của flutter_test) để golden giống
/// máy thật. Gọi trong `setUpAll` hoặc `flutter_test_config.dart`.
Future<void> napFontThat() async {
  if (_daNap) return;
  final loader = FontLoader(
    'packages/${LbType.fontPackage}/${LbType.fontFamily}',
  );
  for (final t in _trongSo) {
    loader.addFont(
      rootBundle.load(
        'packages/${LbType.fontPackage}/fonts/BeVietnamPro-$t.ttf',
      ),
    );
  }
  await loader.load();
  _daNap = true;
}
