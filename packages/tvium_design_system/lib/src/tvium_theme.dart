import 'package:flutter/material.dart';

import 'tvium_tokens.dart';

abstract final class TviumTheme {
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final canvas = dark ? TviumColors.canvasDark : TviumColors.canvasLight;
    final surface = dark ? TviumColors.surfaceDark : TviumColors.surfaceLight;
    final text = dark ? TviumColors.textDark : TviumColors.textLight;
    final accent = dark ? TviumColors.accentDark : TviumColors.accentLight;
    final muted = dark ? TviumColors.mutedDark : TviumColors.mutedLight;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: TviumColors.canvasDark,
      secondary: accent,
      onSecondary: TviumColors.canvasDark,
      error: TviumColors.error,
      onError: TviumColors.canvasDark,
      surface: surface,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      dividerColor: muted.withValues(alpha: 0.18),
      textTheme: _textTheme(text, muted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? TviumColors.raisedDark : TviumColors.raisedLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TviumRadius.control),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TviumRadius.control),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    );
  }

  static TextTheme _textTheme(Color text, Color muted) {
    return TextTheme(
      displaySmall: TextStyle(
        color: text,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      headlineMedium: TextStyle(
        color: text,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        color: text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: text, fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(color: muted, fontSize: 14, height: 1.4),
      labelLarge: TextStyle(
        color: text,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      labelMedium: TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}
