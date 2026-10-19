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
