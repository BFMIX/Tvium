import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/features/artwork/artwork_reference_store.dart';
import 'package:tvium_app/features/metadata/metadata_gateway_client.dart';
import 'package:tvium_app/features/metadata/metadata_overlay_store.dart';
import 'package:tvium_core/tvium_core.dart';

void main() {
  test(
    'grid artwork reads only cached verified metadata with consent',
    () async {
      final store = MetadataOverlayStore(MemoryArtworkKeyValueStore());
      await store.write(
        sourceId: 'source.test',
        entryId: 'movie.test',
        overlay: MetadataOverlay(
          provider: 'tmdb',
          providerId: '7',
          title: 'Example Movie',
          posterUri: Uri.parse('https://image.tmdb.org/t/p/w500/poster.jpg'),
          verified: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [metadataOverlayStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(
          metadataCachedOverlayProvider((
            sourceId: 'source.test',
            entryId: 'movie.test',
            enabled: false,
          )).future,
        ),
        isNull,
      );
      expect(
        (await container.read(
          metadataCachedOverlayProvider((
            sourceId: 'source.test',
            entryId: 'movie.test',
            enabled: true,
          )).future,
        ))?.posterUri?.host,
        'image.tmdb.org',
      );
    },
  );

  test('remembers online metadata consent between app launches', () async {
    final backend = MemoryArtworkKeyValueStore();
    await MetadataConsentStore(backend).write(true);
    expect(await MetadataConsentStore(backend).read(), isTrue);
    await MetadataConsentStore(backend).write(false);
    expect(await MetadataConsentStore(backend).read(), isFalse);
  });

  test('keeps verified public artwork after a store is recreated', () async {
    final backend = MemoryArtworkKeyValueStore();
    final first = MetadataOverlayStore(backend);
    await first.write(
      sourceId: 'source.test',
      entryId: 'movie.test',
      overlay: MetadataOverlay(
        provider: 'tmdb',
        providerId: '7',
        title: 'Example Movie',
        overview: 'A synthetic story.',
        posterUri: Uri.parse('https://image.tmdb.org/t/p/w500/poster.jpg'),
        backdropUri: Uri.parse('https://image.tmdb.org/t/p/w1280/backdrop.jpg'),
        verified: true,
      ),
    );

    final restored = await MetadataOverlayStore(backend)
        .read(sourceId: 'source.test', entryId: 'movie.test');
    expect(restored?.title, 'Example Movie');
    expect(restored?.backdropUri?.host, 'image.tmdb.org');
    expect(restored?.verified, isTrue);
    expect(
      await MetadataOverlayStore(backend)
          .read(sourceId: 'other.test', entryId: 'movie.test'),
      isNull,
    );
  });

  test(
    'never caches tentative matches or untrusted artwork addresses',
    () async {
      final store = MetadataOverlayStore(MemoryArtworkKeyValueStore());
      for (final overlay in [
        const MetadataOverlay(
          provider: 'tmdb',
          providerId: '7',
          title: 'Example Movie',
          verified: false,
        ),
        MetadataOverlay(
          provider: 'tmdb',
          providerId: '7',
          title: 'Example Movie',
          verified: true,
          posterUri: Uri.parse('https://private.example.test/poster.jpg'),
        ),
      ]) {
        await store.write(
          sourceId: 'source.test',
          entryId: 'movie.test',
          overlay: overlay,
        );
        expect(
          await store.read(sourceId: 'source.test', entryId: 'movie.test'),
          isNull,
        );
      }
    },
  );

  test(
    'enriches only an opted-in verified hero and caches its artwork',
    () async {
      var calls = 0;
      final store = MetadataOverlayStore(MemoryArtworkKeyValueStore());
      final client = MetadataGatewayClient(
        endpoint: Uri.parse('https://metadata.example.test'),
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{"candidates":[{"id":"7","provider":"tmdb","title":"Example Movie","kind":"movie","year":2020,"backdropUrl":"https://image.tmdb.org/t/p/w1280/backdrop.jpg","license":"TMDB terms"}]}',
            200,
          );
        }),
      );
      final container = ProviderContainer(
        overrides: [
          metadataGatewayProvider.overrideWithValue(client),
          metadataOverlayStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      const request = (
        sourceId: 'source.test',
        entryId: 'movie.test',
        title: 'Example Movie (2020)',
        kind: MediaKind.movie,
        enabled: true,
      );
      final disabled = await container.read(
        metadataHeroOverlayProvider((
          sourceId: request.sourceId,
          entryId: request.entryId,
          title: request.title,
          kind: request.kind,
          enabled: false,
        )).future,
      );
      expect(disabled, isNull);
      expect(calls, 0);
      final overlay = await container.read(
        metadataHeroOverlayProvider(request).future,
      );
      expect(overlay?.backdropUri?.host, 'image.tmdb.org');
      expect(calls, 1);
      expect(
        (await store.read(
          sourceId: request.sourceId,
          entryId: request.entryId,
        ))?.verified,
        isTrue,
      );
    },
  );
}
