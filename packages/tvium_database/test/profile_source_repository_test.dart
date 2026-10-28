import 'dart:io';

import 'package:test/test.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  group('InMemoryProfileSourceRepository', () {
    _sharedSourceContract(() async => InMemoryProfileSourceRepository());
  });

  group('SqlitePlaylistRepository', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'tvium_profile_source_test_',
      );
    });

    tearDown(() => temporaryDirectory.delete(recursive: true));

    _sharedSourceContract(
      () async => SqlitePlaylistRepository.open(
        '${temporaryDirectory.path}/library.sqlite',
      ),
    );

    test(
      'keeps profiles, selection, and shared source after reopening',
      () async {
        final path = '${temporaryDirectory.path}/library.sqlite';
        final repository = SqlitePlaylistRepository.open(path);
        final home = await repository.ensureDefaultProfile();
        final kids = await repository.createProfile('Kids');
        await repository.registerSource(
          _source(id: 'source-1', digest: 'digest-1'),
          home.id,
          <PersistedMediaEntry>[_entry(sourceId: 'source-1')],
        );
        await repository.linkSource(kids.id, 'source-1');
        await repository.setActiveProfile(kids.id);
        await repository.close();

        final reopened = SqlitePlaylistRepository.open(path);
        addTearDown(reopened.close);

        expect((await reopened.activeProfile()).displayName, 'Kids');
        expect(await reopened.profiles(), hasLength(2));
        expect(await reopened.sourcesForProfile(home.id), hasLength(1));
        expect(await reopened.sourcesForProfile(kids.id), hasLength(1));
        expect(await reopened.entriesForPlaylist('source-1'), hasLength(1));
      },
    );
  });
}

void _sharedSourceContract(
  Future<ProfileSourceRepository> Function() createRepository,
) {
  test('searches candidates beyond the first catalog page', () async {
    final repository = await createRepository();
    addTearDown(repository.close);
    final profile = await repository.ensureDefaultProfile();
    final movies = List<PersistedMediaEntry>.generate(
      130,
      (index) => PersistedMediaEntry(
        id: 'movie-$index',
        playlistId: 'source-1',
        sourceReference: 'secret-reference',
        originalName: 'Film $index',
        displayName: index == 129 ? 'Spider-Man' : 'Film $index',
        groupName: 'Movies',
        kind: MediaKind.movie,
      ),
    );
    await repository.registerSource(
      _source(id: 'source-1', digest: 'digest-1'),
      profile.id,
      movies,
    );
    final searchable = repository as SearchableProfileSourceRepository;
    final results = await searchable.searchEntriesForPlaylist(
      'source-1',
      MediaKind.movie,
      'spider man',
    );
    expect(results.map((entry) => entry.displayName), contains('Spider-Man'));
  });

  test(
    'shares one canonical source between profiles without duplication',
    () async {
      final repository = await createRepository();
      addTearDown(repository.close);
      final home = await repository.ensureDefaultProfile();
      final kids = await repository.createProfile('Kids');

      await repository.registerSource(
        _source(id: 'source-1', digest: 'same-account'),
        home.id,
        <PersistedMediaEntry>[_entry(sourceId: 'source-1')],
      );
      await repository.registerSource(
        _source(id: 'duplicate-id', digest: 'same-account'),
        kids.id,
        <PersistedMediaEntry>[_entry(sourceId: 'duplicate-id')],
      );

      final homeSources = await repository.sourcesForProfile(home.id);
      final kidsSources = await repository.sourcesForProfile(kids.id);
      expect(homeSources.single.id, 'source-1');
      expect(kidsSources.single.id, 'source-1');
      expect(await repository.entriesForPlaylist('source-1'), hasLength(1));
      expect(await repository.entriesForPlaylist('duplicate-id'), isEmpty);
    },
  );

  test(
    'rejects duplicate profile names without changing the active profile',
    () async {
      final repository = await createRepository();
      addTearDown(repository.close);
      final home = await repository.ensureDefaultProfile();

      await expectLater(
        repository.createProfile(' home '),
        throwsA(isA<ArgumentError>()),
      );

      expect((await repository.activeProfile()).id, home.id);
      expect(await repository.profiles(), hasLength(1));
    },
  );

  test('renames a profile and source with unique non-empty names', () async {
    final repository = await createRepository();
    addTearDown(repository.close);
    final home = await repository.ensureDefaultProfile();
    await repository.registerSource(
      _source(id: 'source-1', digest: 'digest-1'),
      home.id,
      <PersistedMediaEntry>[_entry(sourceId: 'source-1')],
    );

    await repository.renameProfile(home.id, 'Family');
    await repository.renameSource('source-1', 'Living room TV');

    expect((await repository.activeProfile()).displayName, 'Family');
    expect(
      (await repository.sourcesForProfile(home.id)).single.displayName,
      'Living room TV',
    );
  });

  test(
    'unlinks a shared source and deletes it only after its last link',
    () async {
      final repository = await createRepository();
      addTearDown(repository.close);
      final home = await repository.ensureDefaultProfile();
      final kids = await repository.createProfile('Kids');
      await repository.registerSource(
        _source(id: 'source-1', digest: 'digest-1'),
        home.id,
        <PersistedMediaEntry>[_entry(sourceId: 'source-1')],
      );
      await repository.linkSource(kids.id, 'source-1');

      expect(await repository.unlinkSource(home.id, 'source-1'), isNull);
      expect(await repository.entriesForPlaylist('source-1'), hasLength(1));

      final orphan = await repository.unlinkSource(kids.id, 'source-1');
      expect(orphan?.id, 'source-1');
      expect(await repository.entriesForPlaylist('source-1'), isEmpty);
    },
  );

  test('deletes a profile, activates a remaining profile, and keeps shared sources', () async {
    final repository = await createRepository();
    addTearDown(repository.close);
    final home = await repository.ensureDefaultProfile();
    final kids = await repository.createProfile('Kids');
    await repository.registerSource(
      _source(id: 'source-1', digest: 'digest-1'),
      home.id,
      <PersistedMediaEntry>[_entry(sourceId: 'source-1')],
    );
    await repository.linkSource(kids.id, 'source-1');
    await repository.setActiveProfile(kids.id);

    expect(await repository.deleteProfile(kids.id), isEmpty);
    expect((await repository.activeProfile()).id, home.id);
    expect(await repository.entriesForPlaylist('source-1'), hasLength(1));
    await expectLater(
      repository.deleteProfile(home.id),
      throwsA(isA<ArgumentError>()),
    );
  });
}

IptvSource _source({required String id, required String digest}) {
  return IptvSource(
    id: id,
    displayName: 'Family TV',
    identityDigest: digest,
    secretReference: 'secret-reference',
  );
}

PersistedMediaEntry _entry({required String sourceId}) {
  return PersistedMediaEntry(
    id: 'news',
    playlistId: sourceId,
    sourceReference: 'secret-reference',
    originalName: 'News',
    displayName: 'News',
    groupName: 'News',
    kind: MediaKind.live,
  );
}
