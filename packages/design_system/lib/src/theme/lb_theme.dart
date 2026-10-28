import 'package:design_system/src/tokens/tokens.g.dart';
import 'package:flutter/material.dart';

/// Token không có chỗ trong [ThemeData] (bóng, kính, đủ bộ màu) - lấy bằng
/// `LbThemeExt.of(context)`.
@immutable
class LbThemeExt extends ThemeExtension<LbThemeExt> {
  const new({required this.colors, required this.shadows, required this.glass});

  final LbColors colors;
  final LbShadows shadows;
  final LbGlass glass;

  static const light = LbThemeExt(
    colors: LbColors.light,
    shadows: LbShadows.light,
    glass: LbGlass.light,
  );
  static const dark = LbThemeExt(
    colors: LbColors.dark,
    shadows: LbShadows.dark,
    glass: LbGlass.dark,
  );

  /// Bộ token của theme đang dùng (mặc định sáng nếu cây chưa có [LbTheme]).
  static LbThemeExt of(BuildContext context) =>
      Theme.of(context).extension<LbThemeExt>() ?? light;

  @override
  LbThemeExt copyWith({LbColors? colors, LbShadows? shadows, LbGlass? glass}) =>
      LbThemeExt(
        colors: colors ?? this.colors,
        shadows: shadows ?? this.shadows,
        glass: glass ?? this.glass,
      );

  // Token là hằng rời rạc theo theme: chuyển ở giữa hoạt ảnh là đủ.
  @override
  LbThemeExt lerp(LbThemeExt? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// ThemeData sáng / tối dựng từ design tokens (`design/tokens.json`).
abstract final class LbTheme {
  static final ThemeData light = _tao(Brightness.light);
  static final ThemeData dark = _tao(Brightness.dark);

  static TextTheme _chu(Color mau, Color mauPhu) {
    TextStyle s(TextStyle t, [Color? c]) => t.copyWith(color: c ?? mau);
    return TextTheme(
      displayLarge: s(LbType.display),
      displayMedium: s(LbType.display),
      displaySmall: s(LbType.headline),
      headlineLarge: s(LbType.headline),
      headlineMedium: s(LbType.headline),
      headlineSmall: s(LbType.title),
      titleLarge: s(LbType.title),
      titleMedium: s(LbType.label),
      titleSmall: s(LbType.label),
      bodyLarge: s(LbType.body),
      bodyMedium: s(LbType.bodySmall),
      bodySmall: s(LbType.caption, mauPhu),
      labelLarge: s(LbType.label),
      labelMedium: s(LbType.caption),
      labelSmall: s(LbType.caption),
    );
  }

  static ThemeData _tao(Brightness sang) {
    final c = sang == Brightness.light ? LbColors.light : LbColors.dark;
    final ext = sang == Brightness.light ? LbThemeExt.light : LbThemeExt.dark;
    final scheme = ColorScheme(
      brightness: sang,
      primary: c.primaryDeep,
      onPrimary: c.onPrimaryDeep,
      primaryContainer: c.primary,
      onPrimaryContainer: c.onPrimary,
      secondary: c.secondary,
      onSecondary: c.onPrimaryDeep,
      // Nền chỉ báo tab / chip đang chọn: cyan nhạt, chữ + icon màu chữ chính.
      secondaryContainer: c.primary.withValues(alpha: 0.24),
      onSecondaryContainer: c.text,
      tertiary: c.accentStrong,
      onTertiary: c.onAccent,
      error: c.dangerStrong,
      onError: c.onDanger,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.bg,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.outlineStrong,
      outlineVariant: c.outline,
      scrim: c.scrim,
    );
    final chu = _chu(c.text, c.textMuted);
    return ThemeData(
      useMaterial3: true,
      brightness: sang,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      fontFamily: LbType.fontFamily,
      package: LbType.fontPackage,
      textTheme: chu,
      iconTheme: IconThemeData(color: c.text, size: 24),
      extensions: [ext],
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primary.withValues(alpha: 0.24),
        labelTextStyle: WidgetStatePropertyAll(chu.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? c.text : c.textMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primary.withValues(alpha: 0.24),
        selectedIconTheme: IconThemeData(size: 24, color: c.text),
        unselectedIconTheme: IconThemeData(size: 24, color: c.textMuted),
        selectedLabelTextStyle: chu.labelMedium,
        unselectedLabelTextStyle: chu.labelMedium?.copyWith(color: c.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: chu.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LbRadius.lg),
          side: BorderSide(color: c.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primaryDeep,
          foregroundColor: c.onPrimaryDeep,
          textStyle: LbType.label,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LbRadius.md),
          ),
        ),
      ),
    );
  }
}
