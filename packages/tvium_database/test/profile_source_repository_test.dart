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

    test('keeps category visibility after reopening', () async {
      final path = '${temporaryDirectory.path}/library.sqlite';
      final repository = SqlitePlaylistRepository.open(path);
      final profile = await repository.ensureDefaultProfile();
      await repository.registerSource(
        _source(id: 'source-1', digest: 'digest-1'),
        profile.id,
        <PersistedMediaEntry>[_entry(sourceId: 'source-1')],
      );
      final category = (await repository.categoriesForProfile(
        profile.id,
        MediaKind.live,
      )).single;
      await repository.setCategoryVisible(
        profileId: profile.id,
        sourceId: category.sourceId,
        kind: category.kind,
        groupName: category.groupName,
        visible: false,
      );
      await repository.close();

      final reopened = SqlitePlaylistRepository.open(path);
      addTearDown(reopened.close);
      expect(
        (await reopened.categoriesForProfile(
          profile.id,
          MediaKind.live,
        )).single.visible,
        isFalse,
      );
    });
  });
}

void _sharedSourceContract(
  Future<ProfileSourceRepository> Function() createRepository,
) {
  test(
    'category visibility is scoped to profile, source, and media kind',
    () async {
      final repository = await createRepository();
      addTearDown(repository.close);
      final home = await repository.ensureDefaultProfile();
      final kids = await repository.createProfile('Kids');
      await repository.registerSource(
        _source(id: 'source-1', digest: 'digest-1'),
        home.id,
        <PersistedMediaEntry>[
          _entry(sourceId: 'source-1'),
          PersistedMediaEntry(
            id: 'movie-1',
            playlistId: 'source-1',
            sourceReference: 'secret-reference',
            originalName: 'Example Movie',
            displayName: 'Example Movie',
            groupName: 'Movies',
            kind: MediaKind.movie,
          ),
        ],
      );
      await repository.linkSource(kids.id, 'source-1');
      final categories = repository as CategoryVisibilityRepository;
      await categories.setCategoryVisible(
        profileId: home.id,
        sourceId: 'source-1',
        kind: MediaKind.movie,
        groupName: 'Movies',
        visible: false,
      );

      expect(
        (await categories.categoriesForProfile(
          home.id,
          MediaKind.movie,
        )).single.visible,
        isFalse,
      );
      expect(
        (await categories.categoriesForProfile(
          kids.id,
          MediaKind.movie,
        )).single.visible,
        isTrue,
      );
      expect(
        (await categories.categoriesForProfile(
          home.id,
          MediaKind.live,
        )).single.visible,
        isTrue,
      );
    },
  );
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
    'visible paging and search skip hidden groups before applying limits',
    () async {
      final repository = await createRepository();
      addTearDown(repository.close);
      final home = await repository.ensureDefaultProfile();
      final kids = await repository.createProfile('Kids');
      await repository.registerSource(
        _source(id: 'source-1', digest: 'digest-1'),
        home.id,
        <PersistedMediaEntry>[
          for (var index = 0; index < 12; index++)
            PersistedMediaEntry(
              id: 'hidden-$index',
              playlistId: 'source-1',
              sourceReference: 'test-reference',
              originalName: 'News $index',
              displayName: 'News $index',
              groupName: 'Hidden',
              kind: MediaKind.live,
            ),
          PersistedMediaEntry(
            id: 'visible',
            playlistId: 'source-1',
            sourceReference: 'test-reference',
            originalName: 'News Visible',
            displayName: 'News Visible',
            groupName: 'Visible',
            kind: MediaKind.live,
          ),
        ],
      );
      await repository.linkSource(kids.id, 'source-1');
      await (repository as CategoryVisibilityRepository).setCategoryVisible(
        profileId: home.id,
        sourceId: 'source-1',
        kind: MediaKind.live,
        groupName: 'Hidden',
        visible: false,
      );
      final paged = repository as PagedProfileSourceRepository;
      final searchable = repository as SearchableProfileSourceRepository;
      expect(
        await paged.countEntriesForPlaylist(
          'source-1',
          MediaKind.live,
          profileId: home.id,
        ),
        1,
      );
      expect(
        (await paged.entriesPageForPlaylist(
          'source-1',
          MediaKind.live,
          profileId: home.id,
          offset: 0,
          limit: 1,
        )).single.id,
        'visible',
      );
      expect(
        (await searchable.searchEntriesForPlaylist(
          'source-1',
          MediaKind.live,
          'News',
          profileId: home.id,
          limit: 1,
        )).single.id,
        'visible',
      );
      expect(
        await paged.countEntriesForPlaylist(
          'source-1',
          MediaKind.live,
          profileId: kids.id,
        ),
        13,
      );
    },
  );

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
