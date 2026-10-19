import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/import/m3u_import_persistence.dart';
import 'package:tvium_app/features/import/playlist_import_controller.dart';
import 'package:tvium_app/features/sources/source_identity_service.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

void main() {
  test('restores an imported M3U catalog after database restart', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'tvium_m3u_restart_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final databasePath = '${temporaryDirectory.path}/library.sqlite';
    final repository = SqlitePlaylistRepository.open(databasePath);
    final secureStore = _MemorySecureKeyValueStore();
    final persistence = DefaultM3uImportPersistence(
      repositoryLoader: () async => repository,
      secureStore: SecureM3uSourceStore(secureStore),
      identityService: SourceIdentityService(secureStore),
      referenceFactory: () => 'm3u-fixture-source',
    );
    final controller = PlaylistImportController(persistence: persistence);

    await controller.importSource(
      const _MemorySource(),
      descriptor: const M3uSourceDescriptor.url(
        displayName: 'Fixture TV',
        location: 'https://playlist.example.test/list.m3u',
      ),
    );
    controller.dispose();
    await repository.close();

    final reopened = SqlitePlaylistRepository.open(databasePath);
    addTearDown(reopened.close);
    final activeProfile = await reopened.activeProfile();
    final sources = await reopened.sourcesForProfile(activeProfile.id);
    final entries = await reopened.entriesForPlaylist(sources.single.id);

    expect(sources.single.displayName, 'Fixture TV');
    expect(entries.single.originalName, 'Demo News');
  });

  test(
    'resolves a restored M3U item without persisting its stream URL',
    () async {
      final secureBackend = _MemorySecureKeyValueStore();
      final secureStore = SecureM3uSourceStore(secureBackend);
      const descriptor = M3uSourceDescriptor.url(
        displayName: 'Fixture TV',
        location: 'https://playlist.example.test/list.m3u',
      );
      await secureStore.write('m3u-fixture-source', descriptor);
      final parsed = <M3uEntry>[];
      await for (final event in const M3uParser().parse(
        const _MemorySource().readLines(),
      )) {
        if (event case M3uBatch(:final entries)) parsed.addAll(entries);
      }
      final resolver = DefaultM3uPlaybackResolver(
        secureStore: secureStore,
        sourceFactory: (_) => const _MemorySource(),
      );

      final uri = await resolver.resolve(
        'm3u-fixture-source',
        parsed.single.id,
      );

      expect(uri, Uri.parse('https://stream.example.test/live/news.m3u8'));
      expect(secureBackend.valuesJoined, contains('playlist.example.test'));
      expect(
        secureBackend.valuesJoined,
        isNot(contains('stream.example.test')),
      );
    },
  );

  test(
    'relinks a retained copy to the previously selected file source',
    () async {
      final repository = InMemoryProfileSourceRepository();
      final secureBackend = _MemorySecureKeyValueStore();
      var reference = 0;
      final persistence = DefaultM3uImportPersistence(
        repositoryLoader: () async => repository,
        secureStore: SecureM3uSourceStore(secureBackend),
        identityService: SourceIdentityService(secureBackend),
        referenceFactory: () => 'm3u-source-${reference++}',
      );
      final controller = PlaylistImportController(persistence: persistence);
      addTearDown(controller.dispose);
      const selectedPath = '/fixtures/selected-playlist.m3u';

      await controller.importSource(
        const _MemorySource(),
        descriptor: const M3uSourceDescriptor.file(
          displayName: 'Fixture TV',
          location: selectedPath,
        ),
      );
      await controller.importSource(
        const _MemorySource(),
        descriptor: const M3uSourceDescriptor.file(
          displayName: 'Fixture TV',
          location: '/private/managed-playlist.m3u',
          identityLocation: selectedPath,
        ),
      );

      final profile = await repository.activeProfile();
      final sources = await repository.sourcesForProfile(profile.id);
      expect(sources, hasLength(1));
      final stored = await SecureM3uSourceStore(secureBackend)
          .read(sources.single.secretReference);
      expect(stored?.location, '/private/managed-playlist.m3u');
    },
  );

  test('refreshes a connected M3U source in place', () async {
    final repository = InMemoryProfileSourceRepository();
    final secureBackend = _MemorySecureKeyValueStore();
    final secureStore = SecureM3uSourceStore(secureBackend);
    final persistence = DefaultM3uImportPersistence(
      repositoryLoader: () async => repository,
      secureStore: secureStore,
      identityService: SourceIdentityService(secureBackend),
      referenceFactory: () => 'm3u-source',
    );
    final controller = PlaylistImportController(persistence: persistence);
    addTearDown(controller.dispose);
    const descriptor = M3uSourceDescriptor.url(
      displayName: 'Fixture TV',
      location: 'https://playlist.example.test/list.m3u',
    );
    await controller.importSource(
      const _MemorySource(),
      descriptor: descriptor,
    );
    final profile = await repository.activeProfile();
    final source = (await repository.sourcesForProfile(profile.id)).single;
    final refresh = M3uSourceRefreshService(
      secureStore: secureStore,
      persistence: persistence,
      sourceFactory: (_) => const _UpdatedMemorySource(),
    );

    final count = await refresh.refresh(source.secretReference);

    expect(count, 2);
    final entries = await repository.entriesForPlaylist(source.id);
    expect(entries.map((entry) => entry.originalName), [
      'Demo News',
      'Demo Cinema',
    ]);
  });
}

final class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  String get valuesJoined => _values.values.join();

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

final class _MemorySource implements M3uSource {
  const _MemorySource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 tvg-id="news" group-title="News",Demo News',
    'https://stream.example.test/live/news.m3u8',
  ]);
}

final class _UpdatedMemorySource implements M3uSource {
  const _UpdatedMemorySource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 tvg-id="news" group-title="News",Demo News',
    'https://stream.example.test/live/news.m3u8',
    '#EXTINF:-1 group-title="Cinema",Demo Cinema',
    'https://stream.example.test/vod/cinema.mp4',
  ]);
}
