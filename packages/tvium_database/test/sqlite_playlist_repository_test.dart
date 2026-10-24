import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'tvium_database_test_',
    );
    databasePath = '${temporaryDirectory.path}/library.sqlite';
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('keeps playlist entries after closing and reopening', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    await repository.replaceEntries('primary', <PersistedMediaEntry>[
      _entry(id: 'news', playlistId: 'primary', group: 'News'),
      _entry(id: 'sport', playlistId: 'primary', group: 'Sports'),
    ]);
    await repository.close();

    final reopened = SqlitePlaylistRepository.open(databasePath);
    addTearDown(reopened.close);

    final entries = await reopened.entriesForPlaylist('primary');
    expect(entries.map((entry) => entry.id), <String>['news', 'sport']);
    expect(entries.first.sourceReference, 'source-news');
  });

  test('preserves the non-secret EPG channel identifier', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    await repository.replaceEntries('primary', <PersistedMediaEntry>[
      PersistedMediaEntry(
        id: 'news',
        playlistId: 'primary',
        sourceReference: 'source-news',
        originalName: 'Fixture News',
        displayName: 'Fixture News',
        groupName: 'News',
        kind: MediaKind.live,
        epgChannelId: 'fixture.news.test',
      ),
    ]);

    final entries = await repository.entriesForPlaylist('primary');

    expect(entries.single.epgChannelId, 'fixture.news.test');
  });

  test('stores and reloads a 5,021-item synthetic catalog', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    final entries = List<PersistedMediaEntry>.generate(
      5021,
      (index) => _entry(
        id: 'fixture-$index',
        playlistId: 'primary',
        group: 'Synthetic',
      ),
      growable: false,
    );

    await repository.replaceEntries('primary', entries);
    final restored = await repository.entriesForPlaylist('primary');

    expect(restored, hasLength(5021));
    expect(restored.first.id, 'fixture-0');
    expect(restored.last.id, 'fixture-5020');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('migrates a version one database without losing entries', () async {
    _createVersionOneDatabase(databasePath);

    final repository = SqlitePlaylistRepository.open(databasePath);
    final entries = await repository.entriesForPlaylist('legacy');
    await repository.close();

    expect(entries, hasLength(1));
    expect(entries.single.displayName, 'Legacy News');

    final migrated = sqlite3.open(databasePath);
    addTearDown(migrated.close);
    expect(migrated.userVersion, 5);
    final columns = migrated.select('PRAGMA table_info(media_entries)');
    expect(columns.map((row) => row['name']), contains('search_name'));
  });
}

PersistedMediaEntry _entry({
  required String id,
  required String playlistId,
  required String group,
}) {
  return PersistedMediaEntry(
    id: id,
    playlistId: playlistId,
    sourceReference: 'source-$id',
    originalName: id,
    displayName: id,
    groupName: group,
    kind: MediaKind.live,
  );
}

void _createVersionOneDatabase(String path) {
  final database = sqlite3.open(path);
  try {
    database.execute('''
      CREATE TABLE media_entries (
        id TEXT NOT NULL,
        playlist_id TEXT NOT NULL,
        source_reference TEXT NOT NULL,
        original_name TEXT NOT NULL,
        display_name TEXT NOT NULL,
        group_name TEXT NULL,
        kind TEXT NOT NULL,
        PRIMARY KEY (playlist_id, id)
      )
    ''');
    database.execute(
      '''
      INSERT INTO media_entries (
        id,
        playlist_id,
        source_reference,
        original_name,
        display_name,
        group_name,
        kind
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
      <Object?>[
        'legacy-news',
        'legacy',
        'source-legacy-news',
        'Legacy News',
        'Legacy News',
        'News',
        'live',
      ],
    );
    database.userVersion = 1;
  } finally {
    database.close();
  }
}
