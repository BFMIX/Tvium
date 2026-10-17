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
    final raised = dark ? TviumColors.raisedDark : TviumColors.raisedLight;
    final onAccent = dark ? TviumColors.canvasDark : Colors.white;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: raised,
      onPrimaryContainer: text,
      secondary: dark ? TviumColors.accentDeep : TviumColors.accentLight,
      onSecondary: onAccent,
      secondaryContainer: raised,
      onSecondaryContainer: text,
      tertiary: TviumColors.amber,
      onTertiary: TviumColors.canvasDark,
      error: TviumColors.live,
      onError: TviumColors.canvasDark,
      surface: surface,
      onSurface: text,
      outline: muted.withValues(alpha: 0.42),
      outlineVariant: muted.withValues(alpha: 0.18),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TviumRadius.control),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TviumRadius.card),
      side: BorderSide(color: muted.withValues(alpha: 0.16)),
    );
    final buttonText = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      cardColor: surface,
      focusColor: accent,
      hoverColor: accent.withValues(alpha: 0.08),
      highlightColor: accent.withValues(alpha: 0.12),
      splashColor: accent.withValues(alpha: 0.12),
      disabledColor: muted.withValues(alpha: 0.38),
      dividerColor: muted.withValues(alpha: 0.18),
      textTheme: _textTheme(text, muted),
      iconTheme: IconThemeData(color: text, size: 24),
      primaryIconTheme: IconThemeData(color: onAccent, size: 24),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: muted, fontSize: 16),
        labelStyle: TextStyle(color: muted, fontSize: 16),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TviumRadius.control),
          borderSide: BorderSide(color: muted.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TviumRadius.control),
          borderSide: BorderSide(color: muted.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TviumRadius.control),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TviumRadius.control),
          borderSide: const BorderSide(color: TviumColors.live),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TviumRadius.control),
          borderSide: const BorderSide(color: TviumColors.live, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return muted.withValues(alpha: 0.2);
            }
            return accent;
          }),
          foregroundColor: WidgetStatePropertyAll(onAccent),
          overlayColor: WidgetStatePropertyAll(
            text.withValues(alpha: dark ? 0.14 : 0.09),
          ),
          textStyle: WidgetStatePropertyAll(buttonText),
          shape: WidgetStatePropertyAll(controlShape),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: text, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          foregroundColor: WidgetStatePropertyAll(text),
          overlayColor: WidgetStatePropertyAll(accent.withValues(alpha: 0.1)),
          textStyle: WidgetStatePropertyAll(buttonText),
          shape: WidgetStatePropertyAll(controlShape),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: accent, width: 2);
            }
            return BorderSide(color: muted.withValues(alpha: 0.4));
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: WidgetStatePropertyAll(accent),
          overlayColor: WidgetStatePropertyAll(accent.withValues(alpha: 0.1)),
          textStyle: WidgetStatePropertyAll(buttonText),
          shape: WidgetStatePropertyAll(controlShape),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        selectedColor: accent.withValues(alpha: 0.18),
        disabledColor: raised.withValues(alpha: 0.5),
        labelStyle: TextStyle(
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: accent,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        checkmarkColor: accent,
        side: BorderSide(color: muted.withValues(alpha: 0.22)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TviumRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: dark ? TviumColors.canvasDarkSecondary : surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : muted,
            size: 26,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected) ? text : muted,
            fontSize: 13,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        minWidth: 88,
        minExtendedWidth: 240,
        elevation: 0,
        backgroundColor: dark ? TviumColors.canvasDarkSecondary : surface,
        indicatorColor: accent.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: accent, size: 28),
        unselectedIconTheme: IconThemeData(color: muted, size: 26),
        selectedLabelTextStyle: TextStyle(
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: muted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TviumRadius.surface),
          side: BorderSide(color: muted.withValues(alpha: 0.2)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TviumRadius.surface),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        selectedColor: accent,
        selectedTileColor: accent.withValues(alpha: 0.1),
        minTileHeight: 56,
        shape: controlShape,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: raised,
          borderRadius: BorderRadius.circular(TviumRadius.control),
          border: Border.all(color: muted.withValues(alpha: 0.22)),
        ),
        textStyle: TextStyle(
          color: text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.hovered)
              ? accent
              : muted.withValues(alpha: 0.56);
        }),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(TviumRadius.pill),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    );
  }

  static TextTheme _textTheme(Color text, Color muted) {
    return TextTheme(
      displayLarge: TextStyle(
        color: text,
        fontSize: 64,
        height: 1.02,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.2,
      ),
      displayMedium: TextStyle(
        color: text,
        fontSize: 48,
        height: 1.06,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.6,
      ),
      displaySmall: TextStyle(
        color: text,
        fontSize: 40,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineLarge: TextStyle(
        color: text,
        fontSize: 32,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      headlineMedium: TextStyle(
        color: text,
        fontSize: 28,
        height: 1.16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        color: text,
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      titleLarge: TextStyle(
        color: text,
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: text,
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: TextStyle(
        color: text,
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: text, fontSize: 18, height: 1.45),
      bodyMedium: TextStyle(color: text, fontSize: 16, height: 1.45),
      bodySmall: TextStyle(color: muted, fontSize: 14, height: 1.4),
      labelLarge: TextStyle(
        color: text,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        color: muted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelSmall: TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
