import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/artwork/artwork_image.dart';
import 'package:tvium_app/features/artwork/artwork_reference_store.dart';
import 'package:tvium_app/features/library/library_bootstrap_controller.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';
import 'package:tvium_app/features/xtream/xtream_connection_service.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
  test(
    'catalog pages cross source boundaries without dropping entries',
    () async {
      final repository = InMemoryProfileSourceRepository();
      final profile = await repository.ensureDefaultProfile();
      const first = IptvSource(
        id: 'source-a',
        displayName: 'First',
        identityDigest: 'digest-a',
        secretReference: 'secret-a',
      );
      const second = IptvSource(
        id: 'source-b',
        displayName: 'Second',
        identityDigest: 'digest-b',
        secretReference: 'secret-b',
      );
      for (final source in [first, second]) {
        await repository.registerSource(
          source,
          profile.id,
          List.generate(
            80,
            (index) => PersistedMediaEntry(
              id: '${source.id}:$index',
              playlistId: source.id,
              sourceReference: source.secretReference,
              originalName: 'Movie $index',
              displayName: 'Movie $index',
              groupName: 'Fixture',
              kind: MediaKind.movie,
            ),
          ),
        );
      }
      final page = await readCatalogPage(
        repository,
        [first, second],
        MediaKind.movie,
        offset: 100,
      );
      expect(page, hasLength(60));
      expect(page.first.id, 'source-b:20');
      expect(page.last.id, 'source-b:79');
    },
  );
  test('bootstrap retains a bounded page for each media kind', () async {
    final repository = InMemoryProfileSourceRepository();
    final profile = await repository.ensureDefaultProfile();
    const source = IptvSource(
      id: 'bounded-source',
      displayName: 'Fixture',
      identityDigest: 'bounded-digest',
      secretReference: 'fixture-secret',
    );
    await repository.registerSource(
      source,
      profile.id,
      List.generate(
        1500,
        (index) => PersistedMediaEntry(
          id: 'movie:$index',
          playlistId: source.id,
          sourceReference: 'fixture-secret',
          originalName: 'Fixture Movie $index',
          displayName: 'Fixture Movie $index',
          groupName: 'Fixture',
          kind: MediaKind.movie,
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWith((ref) async => repository),
        artworkReferenceStoreProvider.overrideWithValue(
          ArtworkReferenceStore(MemoryArtworkKeyValueStore()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final snapshot = await container.read(libraryBootstrapProvider.future);
    expect(snapshot.catalogTotals[MediaKind.movie], 1500);
    expect(snapshot.entries, hasLength(libraryPageSize));
    expect(snapshot.entries.last.id, 'movie:119');
    expect(snapshot.artwork[source.id], isEmpty);
  });
  test('reads only selected artwork references from a large source', () async {
    final store = ArtworkReferenceStore(MemoryArtworkKeyValueStore());
    await store.write('source', {
      for (var index = 0; index < 250; index++)
        'movie:$index': Uri.parse('https://art.example.test/$index.jpg'),
    });
    final selected = await store.readSelected('source', {
      'movie:0',
      'movie:249',
    });
    expect(selected.keys, {'movie:0', 'movie:249'});
  });
  testWidgets('opens later catalog pages without loading every movie', (
    tester,
  ) async {
    final repository = InMemoryProfileSourceRepository();
    final profile = await repository.ensureDefaultProfile();
    const source = IptvSource(
      id: 'large-source',
      displayName: 'Fixture',
      identityDigest: 'large-digest',
      secretReference: 'fixture-secret',
    );
    await repository.registerSource(
      source,
      profile.id,
      List.generate(
        260,
        (index) => PersistedMediaEntry(
          id: 'movie:$index',
          playlistId: source.id,
          sourceReference: 'fixture-secret',
          originalName: 'Fixture Movie $index',
          displayName: 'Fixture Movie $index',
          groupName: 'Fixture',
          kind: MediaKind.movie,
        ),
      ),
    );
    await tester.pumpWidget(TviumApp(profileSourceRepository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('catalog-pagination')), findsOneWidget);
    expect(find.text('1–120 / 260'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalog-next-page')));
    await tester.pumpAndSettle();
    expect(find.text('121–240 / 260'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalog-next-page')));
    await tester.pumpAndSettle();
    expect(find.text('241–260 / 260'), findsOneWidget);
  });
  testWidgets('organizes a saved catalog after showing the first frame', (
    tester,
  ) async {
    final repository = InMemoryProfileSourceRepository();
    final profile = await repository.ensureDefaultProfile();
    await repository.registerSource(
      const IptvSource(
        id: 'source-1',
        displayName: 'Fixture TV',
        identityDigest: 'v1:fixture-digest',
        secretReference: 'fixture-secret-reference',
      ),
      profile.id,
      const <PersistedMediaEntry>[
        PersistedMediaEntry(
          id: 'live:news',
          playlistId: 'source-1',
          sourceReference: 'fixture-secret-reference',
          originalName: 'Fixture News',
          displayName: 'Fixture News',
          groupName: 'News',
          kind: MediaKind.live,
        ),
      ],
    );

    await tester.pumpWidget(TviumApp(profileSourceRepository: repository));
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.pump();
      if (find
          .byKey(const ValueKey('library-organizing'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const ValueKey('library-organizing')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('destination-live')), findsOneWidget);
  });

  testWidgets('restores the active profile catalog on startup', (tester) async {
    final repository = InMemoryProfileSourceRepository();
    final home = await repository.ensureDefaultProfile();
    const source = IptvSource(
      id: 'source-1',
      displayName: 'Fixture TV',
      identityDigest: 'v1:fixture-digest',
      secretReference: 'fixture-secret-reference',
    );
    await repository.registerSource(
      source,
      home.id,
      const <PersistedMediaEntry>[
        PersistedMediaEntry(
          id: 'live:news',
          playlistId: 'source-1',
          sourceReference: 'fixture-secret-reference',
          originalName: 'Fixture News',
          displayName: 'Fixture News',
          groupName: 'News',
          kind: MediaKind.live,
          externalId: 'news',
          containerExtension: 'ts',
        ),
      ],
    );

    final artwork = ArtworkReferenceStore(MemoryArtworkKeyValueStore());
    await artwork.write('source-1', {
      'live:news': Uri.parse('https://images.example.test/logo.png'),
    });
    await tester.pumpWidget(
      TviumApp(
        profileSourceRepository: repository,
        artworkReferenceStore: artwork,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();

    expect(find.text('Fixture News'), findsOneWidget);
    expect(
      tester
          .widgetList<ArtworkImage>(find.byType(ArtworkImage))
          .any((image) => image.uri?.path == '/logo.png'),
      isTrue,
    );
    expect(find.text('Welcome to Tvium'), findsNothing);
  });

  testWidgets('switches to the selected profile catalog', (tester) async {
    final repository = InMemoryProfileSourceRepository();
    final home = await repository.ensureDefaultProfile();
    final kids = await repository.createProfile('Kids');
    await repository.registerSource(
      const IptvSource(
        id: 'home-source',
        displayName: 'Home TV',
        identityDigest: 'v1:home-digest',
        secretReference: 'home-secret-reference',
      ),
      home.id,
      const <PersistedMediaEntry>[
        PersistedMediaEntry(
          id: 'live:home',
          playlistId: 'home-source',
          sourceReference: 'home-secret-reference',
          originalName: 'Home Channel',
          displayName: 'Home Channel',
          groupName: 'Home',
          kind: MediaKind.live,
        ),
      ],
    );
    await repository.registerSource(
      const IptvSource(
        id: 'kids-source',
        displayName: 'Kids TV',
        identityDigest: 'v1:kids-digest',
        secretReference: 'kids-secret-reference',
      ),
      kids.id,
      const <PersistedMediaEntry>[
        PersistedMediaEntry(
          id: 'live:kids',
          playlistId: 'kids-source',
          sourceReference: 'kids-secret-reference',
          originalName: 'Kids Channel',
          displayName: 'Kids Channel',
          groupName: 'Kids',
          kind: MediaKind.live,
        ),
      ],
    );

    await tester.pumpWidget(TviumApp(profileSourceRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    expect(find.text('Home Channel'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Kids'));
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 30 && find.text('Kids Channel').evaluate().isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Home Channel'), findsNothing);
    expect(find.text('Kids Channel'), findsOneWidget);
  });

  testWidgets('shows a safe recovery message when restored playback fails', (
    tester,
  ) async {
    final repository = InMemoryProfileSourceRepository();
    final home = await repository.ensureDefaultProfile();
    await repository.registerSource(
      const IptvSource(
        id: 'source-1',
        displayName: 'Fixture TV',
        identityDigest: 'v1:fixture-digest',
        secretReference: 'missing-secret-reference',
      ),
      home.id,
      const <PersistedMediaEntry>[
        PersistedMediaEntry(
          id: 'live:news',
          playlistId: 'source-1',
          sourceReference: 'missing-secret-reference',
          originalName: 'Fixture News',
          displayName: 'Fixture News',
          groupName: 'News',
          kind: MediaKind.live,
          externalId: 'news',
          containerExtension: 'ts',
        ),
      ],
    );

    await tester.pumpWidget(
      TviumApp(
        profileSourceRepository: repository,
        xtreamConnectionService: const _FailingXtreamService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture News'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Playback is unavailable. Reconnect this source and try again.',
      ),
      findsOneWidget,
    );
  });
}

final class _FailingXtreamService implements XtreamConnectionService {
  const _FailingXtreamService();

  @override
  Future<XtreamAddedProfile> addPlaylist(XtreamConnectionInput input) =>
      throw UnimplementedError();

  @override
  Future<Uri> resolveStreamUri(String profileId, XtreamMediaItem item) =>
      throw const XtreamSecretStoreException();

  @override
  Future<XtreamAccountInfo> testConnection(XtreamConnectionInput input) =>
      throw UnimplementedError();
}
