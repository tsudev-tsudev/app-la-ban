import 'package:flutter/material.dart';
import 'package:la_ban/src/flavor.dart';

/// Gốc ứng dụng. Theme, router, i18n thật thêm ở phase A1.
class LaBanApp extends StatelessWidget {
  /// Tạo app cho [flavor].
  const LaBanApp({required this.flavor, super.key});

  /// Môi trường đang chạy.
  final Flavor flavor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: flavor.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text(flavor.appName)),
      ),
    );
  }
}
