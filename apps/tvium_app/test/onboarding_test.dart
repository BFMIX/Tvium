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
}
