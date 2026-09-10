import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';

void main() {
  testWidgets('explains source ownership before the first import', (
    tester,
  ) async {
    await tester.pumpWidget(const TviumApp());

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
}
