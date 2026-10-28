import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/features/artwork/artwork_cache_budget.dart';
import 'package:tvium_app/features/artwork/artwork_image.dart';
import 'package:tvium_app/features/artwork/artwork_reference_store.dart';
import 'package:tvium_app/features/metadata/metadata_details.dart';
import 'package:tvium_app/features/metadata/metadata_gateway_client.dart';
import 'package:tvium_app/features/metadata/metadata_overlay_store.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  testWidgets('Storage shows artwork size and clears it after confirmation', (
    tester,
  ) async {
    var bytes = 1536 * 1024;
    var clears = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsPages(
                context,
                openSection: (section) => showLibrarySettings(
                  context,
                  configured: false,
                  section: section,
                  onReadArtworkStorage: () async => ArtworkCacheStorage(
                    entryCount: bytes == 0 ? 0 : 2,
                    bytes: bytes,
                  ),
                  onClearArtworkCache: () async {
                    clears++;
                    bytes = 0;
                  },
                ),
              ),
              child: const Text('Open settings pages'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings pages'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-page-storage')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1.5 MiB'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear-artwork-cache')));
    await tester.pumpAndSettle();
    expect(clears, 0);
    await tester.tap(find.text('Clear images'));
    await tester.pumpAndSettle();
    expect(clears, 1);
    expect(find.textContaining('0 B'), findsOneWidget);
  });
  setUp(() => metadataEnabled.value = false);
  tearDown(() => metadataEnabled.value = false);

  testWidgets('Settings opens dedicated sections', (tester) async {
    SettingsSection? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsPages(
                context,
                openSection: (section) async {
                  opened = section;
                  await showLibrarySettings(
                    context,
                    configured: false,
                    section: section,
                  );
                },
              ),
              child: const Text('Open settings pages'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings pages'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-page-playlists')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-page-parental')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('settings-page-parental')));
    await tester.pumpAndSettle();
    expect(opened, SettingsSection.parental);
    expect(find.byKey(const ValueKey('parental-pin-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('epg-url-field')), findsNothing);
  });

  testWidgets('Settings explains update checks for development builds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsPages(
                context,
                openSection: (section) => showLibrarySettings(
                  context,
                  configured: false,
                  section: section,
                ),
              ),
              child: const Text('Open settings pages'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings pages'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-page-updates')));
    await tester.pumpAndSettle();

    expect(find.text('Updates'), findsWidgets);
    expect(find.textContaining('development build'), findsOneWidget);
  });

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

  testWidgets('enabled metadata explains a missing local gateway', (
    tester,
  ) async {
    metadataEnabled.value = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [metadataGatewayProvider.overrideWithValue(null)],
        child: const MaterialApp(
          home: Scaffold(
            body: MetadataDetails(
              originalTitle: 'Example Movie (2020)',
              kind: MediaKind.movie,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('local metadata service'), findsOneWidget);
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
          'language': 'fr-FR',
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

  testWidgets('online summary loads localized movie details automatically', (
    tester,
  ) async {
    metadataEnabled.value = true;
    final overlays = MetadataOverlayStore(MemoryArtworkKeyValueStore());
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient((request) async {
        expect(
          (jsonDecode(request.body) as Map<String, dynamic>)['language'],
          'fr-FR',
        );
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'id': 'movie-1',
                'provider': 'tmdb',
                'title': 'Translated Movie',
                'originalTitle': 'Original Movie',
                'kind': 'movie',
                'year': 2020,
                'overview': 'A localized description.',
                'posterUrl': 'https://image.tmdb.org/t/p/w500/poster.jpg',
                'backdropUrl': 'https://image.tmdb.org/t/p/w1280/backdrop.jpg',
                'sourceUrl': 'https://www.themoviedb.org/movie/1',
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
        overrides: [
          metadataGatewayProvider.overrideWithValue(client),
          metadataOverlayStoreProvider.overrideWithValue(overlays),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OnlineMetadataSummary(
              originalTitle: 'Original Movie (2020)',
              kind: MediaKind.movie,
              sourceId: 'source.test',
              entryId: 'movie.test',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A localized description.'), findsOneWidget);
    expect(find.textContaining('Source: tmdb'), findsOneWidget);
    expect(find.byKey(const ValueKey('metadata-backdrop')), findsOneWidget);
    expect(
      (await overlays.read(
        sourceId: 'source.test',
        entryId: 'movie.test',
        originalTitle: 'Original Movie (2020)',
        kind: MediaKind.movie,
      ))?.verified,
      isTrue,
    );
  });

  testWidgets('yearless series shows a tentative result with a warning', (
    tester,
  ) async {
    metadataEnabled.value = true;
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'id': 'series-1',
                'provider': 'tmdb',
                'title': 'Example Series',
                'kind': 'series',
                'year': 2020,
                'overview': 'A possible series description.',
                'license': 'TMDB terms',
              },
            ],
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [metadataGatewayProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: Scaffold(
            body: OnlineMetadataSummary(
              originalTitle: 'Example Series',
              kind: MediaKind.episode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A possible series description.'), findsOneWidget);
    expect(find.textContaining('Possible match'), findsOneWidget);
  });

  testWidgets('online info shows one yearless series candidate as tentative', (
    tester,
  ) async {
    metadataEnabled.value = true;
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'id': 'series-1',
                'provider': 'tmdb',
                'title': 'Example Series',
                'kind': 'series',
                'year': 2020,
                'overview': 'A tentative description.',
                'posterUrl': 'https://image.tmdb.org/t/p/w500/series.jpg',
                'license': 'TMDB terms',
              },
            ],
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [metadataGatewayProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: Scaffold(
            body: MetadataDetails(
              originalTitle: 'Example Series',
              kind: MediaKind.episode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A tentative description.'), findsOneWidget);
    expect(find.textContaining('uncertain'), findsOneWidget);
    expect(find.byType(ArtworkImage), findsOneWidget);
  });

  testWidgets('online info keeps competing series matches hidden', (
    tester,
  ) async {
    metadataEnabled.value = true;
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              for (final year in [2010, 2023])
                {
                  'id': 'series-$year',
                  'provider': 'tmdb',
                  'title': 'Example Series',
                  'kind': 'series',
                  'year': year,
                  'overview': 'Description $year',
                  'license': 'TMDB terms',
                },
            ],
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [metadataGatewayProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: Scaffold(
            body: MetadataDetails(
              originalTitle: 'Example Series',
              kind: MediaKind.episode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('uncertain'), findsOneWidget);
    expect(find.text('Description 2010'), findsNothing);
    expect(find.text('Description 2023'), findsNothing);
  });

  testWidgets('a user can confirm one tentative series poster', (tester) async {
    metadataEnabled.value = true;
    final overlays = MetadataOverlayStore(MemoryArtworkKeyValueStore());
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'id': 'series-1',
                'provider': 'tmdb',
                'title': 'Example Series',
                'kind': 'series',
                'year': 2020,
                'posterUrl': 'https://image.tmdb.org/t/p/w500/series.jpg',
                'license': 'TMDB terms',
              },
            ],
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          metadataGatewayProvider.overrideWithValue(client),
          metadataOverlayStoreProvider.overrideWithValue(overlays),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OnlineMetadataSummary(
              originalTitle: 'Example Series',
              kind: MediaKind.episode,
              sourceId: 'source.test',
              entryId: 'series.test',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Possible match'), findsOneWidget);
    expect(
      await overlays.read(
        sourceId: 'source.test',
        entryId: 'series.test',
        originalTitle: 'Example Series',
        kind: MediaKind.episode,
      ),
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('metadata-confirm-match')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Possible match'), findsNothing);
    expect(
      (await overlays.read(
        sourceId: 'source.test',
        entryId: 'series.test',
        originalTitle: 'Example Series',
        kind: MediaKind.episode,
      ))?.posterUri?.host,
      'image.tmdb.org',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          metadataGatewayProvider.overrideWithValue(client),
          metadataOverlayStoreProvider.overrideWithValue(overlays),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OnlineMetadataSummary(
              originalTitle: 'Example Series',
              kind: MediaKind.episode,
              sourceId: 'source.test',
              entryId: 'series.test',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Possible match'), findsNothing);
  });

  testWidgets('verified metadata stays visible when the gateway is offline', (
    tester,
  ) async {
    metadataEnabled.value = true;
    final overlays = MetadataOverlayStore(MemoryArtworkKeyValueStore());
    await overlays.write(
      sourceId: 'source.test',
      entryId: 'movie.test',
      originalTitle: 'Example Movie (2020)',
      kind: MediaKind.movie,
      overlay: const MetadataOverlay(
        provider: 'tmdb',
        providerId: '7',
        title: 'Example Movie',
        overview: 'Previously verified summary.',
        verified: true,
      ),
    );
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient((_) async => throw StateError('offline')),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          metadataGatewayProvider.overrideWithValue(client),
          metadataOverlayStoreProvider.overrideWithValue(overlays),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OnlineMetadataSummary(
              originalTitle: 'Example Movie (2020)',
              kind: MediaKind.movie,
              sourceId: 'source.test',
              entryId: 'movie.test',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Previously verified summary.'), findsOneWidget);
  });

  testWidgets('verified metadata stays visible without a gateway address', (
    tester,
  ) async {
    metadataEnabled.value = true;
    final overlays = MetadataOverlayStore(MemoryArtworkKeyValueStore());
    await overlays.write(
      sourceId: 'source.test',
      entryId: 'movie.test',
      originalTitle: 'Example Movie (2020)',
      kind: MediaKind.movie,
      overlay: const MetadataOverlay(
        provider: 'tmdb',
        providerId: '7',
        title: 'Example Movie',
        overview: 'Saved public description.',
        verified: true,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          metadataGatewayProvider.overrideWithValue(null),
          metadataOverlayStoreProvider.overrideWithValue(overlays),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OnlineMetadataSummary(
              originalTitle: 'Example Movie (2020)',
              kind: MediaKind.movie,
              sourceId: 'source.test',
              entryId: 'movie.test',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved public description.'), findsOneWidget);
  });

  testWidgets('unconfigured settings keep the preference editable', (
    tester,
  ) async {
    metadataEnabled.value = true;
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
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('online-metadata-toggle')),
    );
    expect(toggle.value, isTrue);
    expect(toggle.onChanged, isNotNull);
    expect(
      find.textContaining('A metadata service is unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('settings persist online metadata consent on this device', (
    tester,
  ) async {
    final consent = MetadataConsentStore(MemoryArtworkKeyValueStore());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showLibrarySettings(
                context,
                configured: true,
                section: SettingsSection.metadata,
                metadataConsentStore: consent,
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('online-metadata-toggle')));
    await tester.pumpAndSettle();
    expect(await consent.read(), isTrue);
  });

  testWidgets('failed consent save does not leave metadata enabled', (
    tester,
  ) async {
    final consent = MetadataConsentStore(_FailingConsentStore());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showLibrarySettings(
                context,
                configured: true,
                section: SettingsSection.metadata,
                metadataConsentStore: consent,
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('online-metadata-toggle')));
    await tester.pumpAndSettle();

    expect(metadataEnabled.value, isFalse);
    expect(find.text('Could not save metadata preference.'), findsOneWidget);
  });

  testWidgets('desktop local gateway keeps metadata opt-in available', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showLibrarySettings(
                  context,
                  configured: ref.read(metadataGatewayProvider) != null,
                  section: SettingsSection.metadata,
                ),
                child: const Text('Open metadata settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open metadata settings'));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('online-metadata-toggle')),
    );
    expect(toggle.onChanged, isNotNull);
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

  testWidgets('playlist page shows refresh outcome beside its button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLibrarySettings(
              context,
              configured: false,
              section: SettingsSection.playlists,
              onRefreshSources: () async => 'Sources refreshed: 0 changes.',
            ),
            child: const Text('Open playlists'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open playlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('refresh-sources')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('playlist-refresh-status')),
      findsOneWidget,
    );
    expect(find.text('Sources refreshed: 0 changes.'), findsOneWidget);
  });

  testWidgets('settings manages connected playlists', (tester) async {
    String? renamed;
    var removed = false;
    var added = false;
    const source = IptvSource(
      id: 'source-1',
      displayName: 'Family TV',
      identityDigest: 'digest',
      secretReference: 'secret',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLibrarySettings(
              context,
              configured: false,
              sources: const [source],
              onAddPlaylist: () async => added = true,
              onRenameSource: (source, name) async => renamed = name,
              onRemoveSource: (source) async => removed = true,
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Family TV'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rename-source-source-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('source-name-field')),
      'Main playlist',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(renamed, 'Main playlist');

    await tester.tap(find.byKey(const ValueKey('remove-source-source-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);

    await tester.tap(find.byKey(const ValueKey('add-playlist')));
    await tester.pumpAndSettle();
    expect(added, isTrue);
  });

  testWidgets('settings refreshes one connected playlist', (tester) async {
    IptvSource? refreshed;
    const source = IptvSource(
      id: 'source-1',
      displayName: 'Family TV',
      identityDigest: 'digest',
      secretReference: 'secret',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLibrarySettings(
              context,
              configured: false,
              sources: const [source],
              onRefreshSource: (source) async {
                refreshed = source;
                return 'Playlist refreshed: no changes.';
              },
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('refresh-source-source-1')));
    await tester.pumpAndSettle();

    expect(refreshed, source);
    expect(find.text('Playlist refreshed: no changes.'), findsOneWidget);
  });

  testWidgets('playlist settings show the last check time', (tester) async {
    const source = IptvSource(
      id: 'source-1',
      displayName: 'Family TV',
      identityDigest: 'digest',
      secretReference: 'secret',
    );
    final checked = DateTime.utc(2026, 1, 1, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLibrarySettings(
              context,
              configured: false,
              sources: const [source],
              lastRefreshAttemptFor: (_) async => checked,
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    final localTime = checked.toLocal().toString().substring(0, 16);
    expect(find.text('Last checked: $localTime'), findsOneWidget);
  });

  testWidgets('settings saves explicit protected categories', (tester) async {
    Set<String>? savedCategories;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLibrarySettings(
              context,
              configured: false,
              availableParentalCategories: const ['Kids', 'Sports'],
              initialBlockedContent: const {'adult'},
              onSaveParentalPin: (pin, blockedContent) async {
                savedCategories = blockedContent;
                return 'Parental controls enabled.';
              },
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    final kidsCategory = find.byKey(const ValueKey('parental-category-kids'));
    await tester.ensureVisible(kidsCategory);
    await tester.pumpAndSettle();
    await tester.tap(kidsCategory);
    final pinField = find.byKey(const ValueKey('parental-pin-field'));
    await tester.ensureVisible(pinField);
    await tester.enterText(pinField, '1234');
    final saveButton = find.byKey(const ValueKey('parental-primary-action'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedCategories, {'adult', 'kids'});
  });
}

final class _FailingConsentStore implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async => throw StateError('No');

  @override
  Future<void> delete(String key) async {}
}
