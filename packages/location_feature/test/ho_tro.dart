import 'dart:convert';
import 'dart:io';

/// Bộ điểm mẫu chuẩn sinh bằng `tools/build/mau-test-vi-tri.py`.
final Map<String, Object?> mauChuan = jsonDecode(
  File('test/du_lieu/mau_chuan.json').readAsStringSync(),
) as Map<String, Object?>;

List<Map<String, Object?>> mau(String khoa) =>
    (mauChuan[khoa]! as List).cast<Map<String, Object?>>();

double so(Object? v) => (v! as num).toDouble();

/// Hiệu góc nhỏ nhất (độ).
double hieuGoc(double a, double b) => ((a - b + 540) % 360 - 180).abs();
