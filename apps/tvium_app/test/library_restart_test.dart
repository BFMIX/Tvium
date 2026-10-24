import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/artwork/artwork_image.dart';
import 'package:tvium_app/features/artwork/artwork_reference_store.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';
import 'package:tvium_app/features/xtream/xtream_connection_service.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
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
