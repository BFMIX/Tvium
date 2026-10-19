import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';

void main() {
  testWidgets('reports a local file picker failure without leaking details', (
    tester,
  ) async {
    await tester.pumpWidget(
      TviumApp(
        localPlaylistPicker: () async {
          throw Exception(
            'password=do-not-display https://private.example.test/list.m3u',
          );
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('m3u-file-action')));
    await tester.pumpAndSettle();

    expect(find.text('The playlist file could not be opened'), findsOneWidget);
    expect(find.textContaining('do-not-display'), findsNothing);
    expect(find.textContaining('private.example.test'), findsNothing);
  });

  testWidgets('conceals a playlist URL until the user reveals it', (
    tester,
  ) async {
    await tester.pumpWidget(const TviumApp());
    await tester.tap(find.byKey(const ValueKey<String>('m3u-url-action')));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('url-visibility-toggle')),
    );
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
  });
}
