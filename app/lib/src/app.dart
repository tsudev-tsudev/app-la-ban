import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:la_ban/src/flavor.dart';

/// Gốc ứng dụng. Theme, router, i18n thật thêm ở phase A1.
class LaBanApp extends StatelessWidget {
  /// Tạo app cho [flavor].
  const new({required this.flavor, super.key});

  /// Môi trường đang chạy.
  final Flavor flavor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: flavor.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: LbColors.light.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cùng biểu tượng, cùng vị trí với splash native -> chuyển mượt.
              const LbLogoDong(size: 128),
              const SizedBox(height: LbSpacing.lg),
              Text(flavor.appName),
            ],
          ),
        ),
      ),
    );
  }
}
