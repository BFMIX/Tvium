import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';

void main() {
  testWidgets('explains source ownership before the first import', (
    tester,
  ) async {
    await tester.pumpWidget(const TviumApp());

    expect(
      find.byKey(const ValueKey<String>('tvium-brand-logo')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Tvium'), findsOneWidget);
    expect(find.text('Welcome to Tvium'), findsOneWidget);
    expect(
      find.text('Add your own IPTV source to get started.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tvium does not provide TV channels, playlists or subscriptions.',
      ),
      findsOneWidget,
    );
    expect(find.text('M3U URL'), findsOneWidget);
    expect(find.text('Import local M3U'), findsOneWidget);
    expect(find.text('Xtream Codes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('m3u-url-action')));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('keeps every source action visible on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TviumApp());

    for (final key in const <String>[
      'm3u-url-action',
      'm3u-file-action',
      'xtream-action',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
    }
  });

  testWidgets('opens a protected Xtream connection form', (tester) async {
    await tester.pumpWidget(const TviumApp());

    await tester.tap(find.byKey(const ValueKey<String>('xtream-action')));
    await tester.pump();

    expect(find.text('Profile name'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Test connection'), findsOneWidget);
    expect(find.text('Add playlist'), findsOneWidget);

    final serverField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('xtream-server-url')),
    );
    final passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('xtream-password')),
    );
    expect(serverField.obscureText, isTrue);
    expect(serverField.enableSuggestions, isFalse);
    expect(passwordField.obscureText, isTrue);
    expect(passwordField.enableSuggestions, isFalse);
  });
}
