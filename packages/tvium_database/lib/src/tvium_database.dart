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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSearchIndex();
    },
    onUpgrade: (migrator, from, to) async {
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

  Future<void> _createSearchIndex() {
    return customStatement(
      'CREATE INDEX IF NOT EXISTS media_entries_search '
      'ON media_entries (playlist_id, search_name)',
    );
  }
}
