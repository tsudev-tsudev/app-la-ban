import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rung nhẹ (test override để đếm).
final rungProvider = Provider<void Function()>(
  (_) => HapticFeedback.selectionClick,
);
