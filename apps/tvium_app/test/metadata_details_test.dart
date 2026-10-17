import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/features/metadata/metadata_details.dart';
import 'package:tvium_app/features/metadata/metadata_gateway_client.dart';
import 'package:tvium_core/tvium_core.dart';

void main() {
  setUp(() => metadataEnabled.value = false);
  tearDown(() => metadataEnabled.value = false);

  testWidgets(
    'details show cleaned and original title without opt-in traffic',
    (tester) async {
      var requests = 0;
      final client = MetadataGatewayClient(
        endpoint: Uri.parse('https://metadata.example.test'),
        client: MockClient((_) async {
          requests++;
          throw StateError('No request expected');
        }),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [metadataGatewayProvider.overrideWithValue(client)],
          child: const MaterialApp(
            home: Scaffold(
              body: MetadataDetails(
                originalTitle: '[EN] Arrival (2016) [4K]',
                kind: MediaKind.movie,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Arrival'), findsOneWidget);
      expect(
        find.text('Original title: [EN] Arrival (2016) [4K]'),
        findsOneWidget,
      );
      expect(find.textContaining('Online metadata is off'), findsOneWidget);
      expect(requests, 0);
    },
  );

  testWidgets('offline failures keep local details and safe error', (
    tester,
  ) async {
    metadataEnabled.value = true;
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient(
        (_) async => throw StateError('secret-network-diagnostic'),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [metadataGatewayProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: Scaffold(
            body: MetadataDetails(
              originalTitle: 'Arrival (2016)',
              kind: MediaKind.movie,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arrival'), findsOneWidget);
    expect(
      find.text('Metadata is unavailable. Your playlist is unchanged.'),
      findsOneWidget,
    );
    expect(find.textContaining('secret-network-diagnostic'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('series details accept a unique title and year match', (
    tester,
  ) async {
    metadataEnabled.value = true;
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {
          'title': 'Example',
          'kind': 'series',
          'year': 2020,
          'language': 'en',
        });
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'id': 'series-1',
                'provider': 'tmdb',
                'title': 'Example',
                'kind': 'series',
                'year': 2020,
                'overview': 'A series overview.',
                'sourceUrl': 'https://www.themoviedb.org/tv/1',
                'license': 'TMDB terms',
              },
            ],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [metadataGatewayProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: Scaffold(
            body: MetadataDetails(
              originalTitle: 'Example (2020)',
              kind: MediaKind.episode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A series overview.'), findsOneWidget);
    expect(find.text('Source: tmdb'), findsOneWidget);
  });

  testWidgets('unconfigured settings show disabled opt-in switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLibrarySettings(context, configured: false),
            child: const Text('Open settings'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(
      find.text('Online metadata is not configured in this build.'),
      findsOneWidget,
    );
  });

  testWidgets('settings refresh connected sources and show a safe summary', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLibrarySettings(
              context,
              configured: false,
              onRefreshSources: () async {
                refreshes++;
                return 'Sources refreshed: 1 added, 0 updated, 0 removed.';
              },
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('refresh-sources')));
    await tester.pumpAndSettle();

    expect(refreshes, 1);
    expect(
      find.text('Sources refreshed: 1 added, 0 updated, 0 removed.'),
      findsOneWidget,
    );
  });
}
