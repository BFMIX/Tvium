import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_design_system/tvium_design_system.dart';

void main() {
  group('TviumTheme.dark', () {
    final theme = TviumTheme.dark();

    test('uses the approved cinematic palette', () {
      expect(theme.scaffoldBackgroundColor, TviumColors.canvasDark);
      expect(theme.colorScheme.primary, TviumColors.accentDark);
      expect(theme.colorScheme.secondary, TviumColors.accentDeep);
      expect(theme.colorScheme.tertiary, TviumColors.amber);
      expect(theme.colorScheme.error, TviumColors.live);
      expect(theme.cardTheme.color, TviumColors.surfaceDark);
    });

    test('keeps primary actions and inputs readable at TV distance', () {
      final buttonStyle = theme.filledButtonTheme.style!;
      expect(
        buttonStyle.minimumSize!.resolve(<WidgetState>{}),
        const Size(64, 52),
      );
      expect(buttonStyle.textStyle!.resolve(<WidgetState>{})!.fontSize, 16);

      final input = theme.inputDecorationTheme;
      expect(
        input.contentPadding,
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );
      expect(input.enabledBorder, isA<OutlineInputBorder>());
      expect(input.focusedBorder, isA<OutlineInputBorder>());
    });

    test('provides coherent cards, chips, and navigation', () {
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.chipTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.navigationBarTheme.height, 72);
      expect(theme.navigationRailTheme.minWidth, 88);
      expect(theme.focusColor, TviumColors.accentDark);
    });
  });
}
