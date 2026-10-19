import 'package:drift/drift.dart';

part 'tvium_database.g.dart';

class MediaEntries extends Table {
  TextColumn get id => text()();

  TextColumn get playlistId => text()();

  TextColumn get sourceReference => text()();

  TextColumn get originalName => text()();

  TextColumn get displayName => text()();

  TextColumn get groupName => text().nullable()();

  TextColumn get kind => text()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  TextColumn get searchName => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{playlistId, id};
}

@DriftDatabase(tables: <Type>[MediaEntries])
final class TviumDatabase extends _$TviumDatabase {
  TviumDatabase(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSearchIndex();
      await _createProfiles();
      await _createEpg();
      await _createUserOverlays();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 3) await _createProfiles();
      if (from == 3) {
        await customStatement(
          'ALTER TABLE catalog_details ADD COLUMN epg_channel_id TEXT',
        );
      }
      if (from < 4) await _createEpg();
      if (from < 5) await _createUserOverlays();
      if (from < 2) {
        await migrator.addColumn(mediaEntries, mediaEntries.position);
        await migrator.addColumn(mediaEntries, mediaEntries.searchName);
        await customStatement(
          'UPDATE media_entries SET search_name = lower(display_name)',
        );
        await _createSearchIndex();
      }
    },
  );

  Future<void> _createProfiles() async {
    await customStatement(
      'CREATE TABLE user_profiles (id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE)',
    );
    await customStatement(
      'CREATE TABLE iptv_sources (id TEXT PRIMARY KEY, name TEXT NOT NULL, digest TEXT NOT NULL UNIQUE, secret_reference TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE profile_sources (profile_id TEXT NOT NULL REFERENCES user_profiles(id), source_id TEXT NOT NULL REFERENCES iptv_sources(id), PRIMARY KEY(profile_id,source_id))',
    );
    await customStatement(
      'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE catalog_details (source_id TEXT NOT NULL, entry_id TEXT NOT NULL, external_id TEXT, extension TEXT, epg_channel_id TEXT, PRIMARY KEY(source_id,entry_id))',
    );
  }

  Future<void> _createSearchIndex() {
    return customStatement(
      'CREATE INDEX IF NOT EXISTS media_entries_search '
      'ON media_entries (playlist_id, search_name)',
    );
  }

  Future<void> _createEpg() async {
    await customStatement('''
      CREATE TABLE epg_channels (
        source_id TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        PRIMARY KEY(source_id, channel_id)
      )
    ''');
    await customStatement('''
      CREATE TABLE epg_programmes (
        source_id TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        start_utc INTEGER NOT NULL,
        stop_utc INTEGER NOT NULL,
        title TEXT NOT NULL,
        title_search TEXT NOT NULL,
        subtitle TEXT,
        description TEXT,
        categories_json TEXT NOT NULL,
        PRIMARY KEY(source_id, channel_id, start_utc, stop_utc, title)
      )
    ''');
    await customStatement('''
      CREATE TABLE epg_channel_links (
        app_channel_id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        strategy TEXT NOT NULL
      )
    ''');
    await customStatement(
      'CREATE INDEX epg_programmes_channel_time '
      'ON epg_programmes(source_id, channel_id, start_utc, stop_utc)',
    );
    await customStatement(
      'CREATE INDEX epg_programmes_search_time '
      'ON epg_programmes(title_search, start_utc, stop_utc)',
    );
    await customStatement(
      'CREATE INDEX epg_channel_links_source '
      'ON epg_channel_links(source_id, channel_id)',
    );
  }

  Future<void> _createUserOverlays() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS favorites (
        profile_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        created_at_utc INTEGER NOT NULL,
        PRIMARY KEY(profile_id, source_id, entry_id)
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS playback_history (
        profile_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        last_played_at_utc INTEGER NOT NULL,
        position_ms INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        PRIMARY KEY(profile_id, source_id, entry_id)
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS playback_history_recent '
      'ON playback_history(profile_id, last_played_at_utc DESC)',
    );
    await customStatement('''
      CREATE TABLE IF NOT EXISTS parental_policies (
        profile_id TEXT PRIMARY KEY,
        pin_digest TEXT NOT NULL,
        blocked_content_json TEXT NOT NULL
      )
    ''');
  }
}
