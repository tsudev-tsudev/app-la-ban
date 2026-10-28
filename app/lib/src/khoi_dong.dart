import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:la_ban/src/app.dart';
import 'package:la_ban/src/flavor.dart';

/// Điểm vào chung của mọi flavor.
void khoiDong(Flavor flavor) {
  WidgetsFlutterBinding.ensureInitialized();
  dangKyGiayPhepFont();
  runApp(ProviderScope(child: LaBanApp(flavor: flavor)));
}
