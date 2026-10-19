import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_epg/tvium_epg.dart';

void main() {
  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'tvium_epg_database_test_',
    );
    databasePath = '${temporaryDirectory.path}/library.sqlite';
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('persists EPG and keeps replacement isolated by source', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    await repository.replaceEpg(
      epgSourceId: 'guide-a.test',
      channels: [_channel('news.a.test', 'News A')],
      programmes: [
        _programme(
          channelId: 'news.a.test',
          title: 'A Current',
          startHour: 10,
          stopHour: 11,
        ),
      ],
      links: [
        _link(
          appChannelId: 'source-a.test:live:1',
          epgSourceId: 'guide-a.test',
          xmltvChannelId: 'news.a.test',
        ),
      ],
    );
    await repository.replaceEpg(
      epgSourceId: 'guide-b.test',
      channels: [_channel('news.b.test', 'News B')],
      programmes: [
        _programme(
          channelId: 'news.b.test',
          title: 'B Current',
          startHour: 10,
          stopHour: 11,
        ),
      ],
      links: [
        _link(
          appChannelId: 'source-b.test:live:1',
          epgSourceId: 'guide-b.test',
          xmltvChannelId: 'news.b.test',
        ),
      ],
    );
    await repository.replaceEpg(
      epgSourceId: 'guide-a.test',
      channels: [_channel('news.a.test', 'News A')],
      programmes: [
        _programme(
          channelId: 'news.a.test',
          title: 'A Refreshed',
          startHour: 10,
          stopHour: 11,
        ),
      ],
      links: [
        _link(
          appChannelId: 'source-a.test:live:1',
          epgSourceId: 'guide-a.test',
          xmltvChannelId: 'news.a.test',
        ),
      ],
    );
    await repository.close();

    final reopened = SqlitePlaylistRepository.open(databasePath);
    addTearDown(reopened.close);
    final at = DateTime.utc(2026, 10, 16, 10, 30);

    expect(
      (await reopened.nowNextForChannel(
        'source-a.test:live:1',
        at,
      )).current?.title,
      'A Refreshed',
    );
    expect(
      (await reopened.nowNextForChannel(
        'source-b.test:live:1',
        at,
      )).current?.title,
      'B Current',
    );
  });

  test('uses half-open intervals and deterministic next ordering', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    await repository.replaceEpg(
      epgSourceId: 'guide.test',
      channels: [_channel('news.test', 'News')],
      programmes: [
        _programme(
          channelId: 'news.test',
          title: 'First',
          startHour: 10,
          stopHour: 11,
        ),
        _programme(
          channelId: 'news.test',
          title: 'Second',
          startHour: 11,
          stopHour: 12,
        ),
        _programme(
          channelId: 'news.test',
          title: 'Third',
          startHour: 12,
          stopHour: 13,
        ),
      ],
      links: [
        _link(
          appChannelId: 'source.test:live:1',
          epgSourceId: 'guide.test',
          xmltvChannelId: 'news.test',
        ),
      ],
    );

    final boundary = await repository.nowNextForChannel(
      'source.test:live:1',
      DateTime.utc(2026, 10, 16, 11),
    );

    expect(boundary.current?.title, 'Second');
    expect(boundary.next?.title, 'Third');
  });

  test('never mixes current and next across concurrent refreshes', () async {
    final previousWarningSetting =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          previousWarningSetting;
    });
    final reader = SqlitePlaylistRepository.open(databasePath);
    await _replaceGeneration(reader, 'A');
    final writer = SqlitePlaylistRepository.open(databasePath);
    addTearDown(reader.close);
    addTearDown(writer.close);

    final writes = Future<void>(() async {
      for (var index = 0; index < 120; index++) {
        await _replaceGeneration(writer, index.isEven ? 'B' : 'A');
      }
    });
    final reads = Future<List<EpgNowNext>>(() async {
      final snapshots = <EpgNowNext>[];
      for (var index = 0; index < 240; index++) {
        snapshots.add(
          await reader.nowNextForChannel(
            'source.test:live:1',
            DateTime.utc(2026, 10, 16, 10, 30),
          ),
        );
      }
      return snapshots;
    });

    final snapshots = await reads;
    await writes;
    for (final snapshot in snapshots) {
      final currentGeneration = snapshot.current?.title.split(' ').first;
      final nextGeneration = snapshot.next?.title.split(' ').first;
      expect(currentGeneration, isNotNull);
      expect(nextGeneration, currentGeneration);
    }
  });

  test('searches bounded overlapping programmes and caps the limit', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    await repository.replaceEpg(
      epgSourceId: 'guide.test',
      channels: [_channel('news.test', 'News')],
      programmes: [
        for (var hour = 0; hour < 4; hour++)
          _programme(
            channelId: 'news.test',
            title: hour == 0 ? 'Morning NEWS' : 'News $hour',
            startHour: 8 + hour,
            stopHour: 9 + hour,
          ),
      ],
      links: [
        _link(
          appChannelId: 'source.test:live:1',
          epgSourceId: 'guide.test',
          xmltvChannelId: 'news.test',
        ),
      ],
    );

    final results = await repository.searchProgrammes(
      query: 'news',
      fromUtc: DateTime.utc(2026, 10, 16, 8, 30),
      toUtc: DateTime.utc(2026, 10, 16, 12),
      limit: 2,
    );

    expect(results.map((programme) => programme.title), [
      'Morning NEWS',
      'News 1',
    ]);
    expect(
      () => repository.searchProgrammes(
        query: 'news',
        fromUtc: DateTime.utc(2026, 10, 16),
        toUtc: DateTime.utc(2026, 10, 17),
        limit: 0,
      ),
      throwsArgumentError,
    );
  });

  test('search tie ordering includes source and channel identifiers', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    for (final source in ['guide-b.test', 'guide-a.test']) {
      final channelId = source.replaceFirst('guide-', 'channel-');
      await repository.replaceEpg(
        epgSourceId: source,
        channels: [_channel(channelId, source)],
        programmes: [
          _programme(
            channelId: channelId,
            title: 'Shared title',
            startHour: 10,
            stopHour: 11,
          ),
        ],
        links: const [],
      );
    }

    final results = await repository.searchProgrammes(
      query: 'shared',
      fromUtc: DateTime.utc(2026, 10, 16),
      toUtc: DateTime.utc(2026, 10, 17),
    );

    expect(results.map((programme) => programme.channelId), [
      'channel-a.test',
      'channel-b.test',
    ]);
  });

  test('prunes expired programmes and reports the deleted count', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    await repository.replaceEpg(
      epgSourceId: 'guide.test',
      channels: [_channel('news.test', 'News')],
      programmes: [
        _programme(
          channelId: 'news.test',
          title: 'Expired',
          startHour: 8,
          stopHour: 9,
        ),
        _programme(
          channelId: 'news.test',
          title: 'Kept',
          startHour: 9,
          stopHour: 10,
        ),
      ],
      links: [
        _link(
          appChannelId: 'source.test:live:1',
          epgSourceId: 'guide.test',
          xmltvChannelId: 'news.test',
        ),
      ],
    );

    expect(
      await repository.pruneEpgBefore(DateTime.utc(2026, 10, 16, 9, 30)),
      1,
    );
    final remaining = await repository.searchProgrammes(
      query: '',
      fromUtc: DateTime.utc(2026, 10, 16),
      toUtc: DateTime.utc(2026, 10, 17),
    );
    expect(remaining.single.title, 'Kept');
  });

  test('rejects invalid replacement without erasing the old cache', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    await repository.replaceEpg(
      epgSourceId: 'guide.test',
      channels: [_channel('news.test', 'News')],
      programmes: [
        _programme(
          channelId: 'news.test',
          title: 'Safe',
          startHour: 10,
          stopHour: 11,
        ),
      ],
      links: [
        _link(
          appChannelId: 'source.test:live:1',
          epgSourceId: 'guide.test',
          xmltvChannelId: 'news.test',
        ),
      ],
    );

    await expectLater(
      repository.replaceEpg(
        epgSourceId: 'guide.test',
        channels: [_channel('other.test', 'Other')],
        programmes: [
          _programme(
            channelId: 'missing.test',
            title: 'Invalid',
            startHour: 10,
            stopHour: 11,
          ),
        ],
        links: const [],
      ),
      throwsArgumentError,
    );

    expect(
      (await repository.nowNextForChannel(
        'source.test:live:1',
        DateTime.utc(2026, 10, 16, 10, 30),
      )).current?.title,
      'Safe',
    );
  });

  test('rolls back a SQL-time duplicate programme failure', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    await _replaceGeneration(repository, 'Safe');
    final duplicate = _programme(
      channelId: 'news.test',
      title: 'Duplicate',
      startHour: 10,
      stopHour: 11,
    );

    await expectLater(
      repository.replaceEpg(
        epgSourceId: 'guide.test',
        channels: [_channel('news.test', 'News')],
        programmes: [duplicate, duplicate],
        links: [
          _link(
            appChannelId: 'source.test:live:1',
            epgSourceId: 'guide.test',
            xmltvChannelId: 'news.test',
          ),
        ],
      ),
      throwsA(anything),
    );

    final snapshot = await repository.nowNextForChannel(
      'source.test:live:1',
      DateTime.utc(2026, 10, 16, 10, 30),
    );
    expect(snapshot.current?.title, 'Safe current');
    expect(snapshot.next?.title, 'Safe next');
  });

  test('explicit remap survives a refresh of the old source', () async {
    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    await _replaceGeneration(
      repository,
      'A',
      extraAppChannelId: 'source.test:live:stale',
    );
    await repository.replaceEpg(
      epgSourceId: 'guide-b.test',
      channels: [_channel('news-b.test', 'News B')],
      programmes: [
        _programme(
          channelId: 'news-b.test',
          title: 'B current',
          startHour: 10,
          stopHour: 11,
        ),
      ],
      links: [
        _link(
          appChannelId: 'source.test:live:1',
          epgSourceId: 'guide-b.test',
          xmltvChannelId: 'news-b.test',
        ),
      ],
    );
    await repository.replaceEpg(
      epgSourceId: 'guide.test',
      channels: [_channel('news.test', 'News')],
      programmes: [
        _programme(
          channelId: 'news.test',
          title: 'A refreshed',
          startHour: 10,
          stopHour: 11,
        ),
      ],
      links: const [],
    );

    expect(
      (await repository.nowNextForChannel(
        'source.test:live:1',
        DateTime.utc(2026, 10, 16, 10, 30),
      )).current?.title,
      'B current',
    );
    final removed = await repository.nowNextForChannel(
      'source.test:live:stale',
      DateTime.utc(2026, 10, 16, 10, 30),
    );
    expect(removed.current, isNull);
    expect(removed.next, isNull);
  });

  test('migrates version 3 without losing media rows', () async {
    _createVersionThreeDatabase(databasePath);

    final repository = SqlitePlaylistRepository.open(databasePath);
    addTearDown(repository.close);
    expect(
      (await repository.entriesForPlaylist('legacy')).single.displayName,
      'Legacy News',
    );
    await repository.replaceEpg(
      epgSourceId: 'guide.test',
      channels: [_channel('legacy.test', 'Legacy News')],
      programmes: const [],
      links: const [],
    );

    final database = sqlite3.open(databasePath);
    addTearDown(database.close);
    expect(database.userVersion, 5);
    expect(
      database.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='epg_programmes'",
      ),
      hasLength(1),
    );
  });
}

EpgChannel _channel(String id, String name) =>
    EpgChannel(id: id, displayName: name);

EpgProgramme _programme({
  required String channelId,
  required String title,
  required int startHour,
  required int stopHour,
}) => EpgProgramme(
  channelId: channelId,
  startUtc: DateTime.utc(2026, 10, 16, startHour),
  stopUtc: DateTime.utc(2026, 10, 16, stopHour),
  title: title,
);

EpgChannelLink _link({
  required String appChannelId,
  required String epgSourceId,
  required String xmltvChannelId,
}) => EpgChannelLink(
  appChannelId: appChannelId,
  epgSourceId: epgSourceId,
  xmltvChannelId: xmltvChannelId,
  strategy: EpgMatchStrategy.exactId,
);

Future<void> _replaceGeneration(
  SqlitePlaylistRepository repository,
  String generation, {
  String? extraAppChannelId,
}) => repository.replaceEpg(
  epgSourceId: 'guide.test',
  channels: [_channel('news.test', 'News')],
  programmes: [
    _programme(
      channelId: 'news.test',
      title: '$generation current',
      startHour: 10,
      stopHour: 11,
    ),
    _programme(
      channelId: 'news.test',
      title: '$generation next',
      startHour: 11,
      stopHour: 12,
    ),
  ],
  links: [
    _link(
      appChannelId: 'source.test:live:1',
      epgSourceId: 'guide.test',
      xmltvChannelId: 'news.test',
    ),
    if (extraAppChannelId != null)
      _link(
        appChannelId: extraAppChannelId,
        epgSourceId: 'guide.test',
        xmltvChannelId: 'news.test',
      ),
  ],
);

void _createVersionThreeDatabase(String path) {
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
        position INTEGER NOT NULL DEFAULT 0,
        search_name TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (playlist_id, id)
      )
    ''');
    database.execute('''
      INSERT INTO media_entries (
        id, playlist_id, source_reference, original_name, display_name,
        group_name, kind, position, search_name
      ) VALUES ('legacy-news', 'legacy', 'source-legacy-news', 'Legacy News',
                'Legacy News', 'News', 'live', 0, 'legacy news')
    ''');
    database.execute('''
      CREATE TABLE user_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE
      )
    ''');
    database.execute('''
      CREATE TABLE iptv_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        digest TEXT NOT NULL UNIQUE,
        secret_reference TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE profile_sources (
        profile_id TEXT NOT NULL REFERENCES user_profiles(id),
        source_id TEXT NOT NULL REFERENCES iptv_sources(id),
        PRIMARY KEY(profile_id, source_id)
      )
    ''');
    database.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE catalog_details (
        source_id TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        external_id TEXT,
        extension TEXT,
        PRIMARY KEY(source_id, entry_id)
      )
    ''');
    database.userVersion = 3;
  } finally {
    database.close();
  }
}
