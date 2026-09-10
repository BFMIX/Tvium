import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tvium_core/tvium_core.dart';

import 'persisted_media_entry.dart';
import 'playlist_repository.dart';
import 'tvium_database.dart';

final class SqlitePlaylistRepository implements PlaylistRepository {
  SqlitePlaylistRepository._(this._database);

  factory SqlitePlaylistRepository.open(String path) {
    return SqlitePlaylistRepository._(
      TviumDatabase(NativeDatabase(File(path))),
    );
  }

  final TviumDatabase _database;

  @override
  Future<void> replaceEntries(
    String playlistId,
    Iterable<PersistedMediaEntry> entries,
  ) async {
    final replacement = entries.toList(growable: false);
    if (replacement.any((entry) => entry.playlistId != playlistId)) {
      throw ArgumentError.value(
        playlistId,
        'playlistId',
        'Every entry must belong to the replaced playlist.',
      );
    }

    await _database.transaction(() async {
      await (_database.delete(
        _database.mediaEntries,
      )..where((row) => row.playlistId.equals(playlistId))).go();
      await _database.batch((batch) {
        batch.insertAll(
          _database.mediaEntries,
          replacement.indexed
              .map((indexed) {
                final (position, entry) = indexed;
                return MediaEntriesCompanion.insert(
                  id: entry.id,
                  playlistId: entry.playlistId,
                  sourceReference: entry.sourceReference,
                  originalName: entry.originalName,
                  displayName: entry.displayName,
                  groupName: Value<String?>(entry.groupName),
                  kind: entry.kind.name,
                  position: Value<int>(position),
                  searchName: Value<String>(entry.displayName.toLowerCase()),
                );
              })
              .toList(growable: false),
        );
      });
    });
  }

  @override
  Future<List<PersistedMediaEntry>> entriesForPlaylist(
    String playlistId,
  ) async {
    final query = _database.select(_database.mediaEntries)
      ..where((row) => row.playlistId.equals(playlistId))
      ..orderBy(<OrderingTerm Function(MediaEntries)>[
        (row) => OrderingTerm.asc(row.position),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<PersistedMediaEntry>> entriesForGroup(
    String playlistId,
    String groupName,
  ) async {
    final query = _database.select(_database.mediaEntries)
      ..where(
        (row) =>
            row.playlistId.equals(playlistId) & row.groupName.equals(groupName),
      )
      ..orderBy(<OrderingTerm Function(MediaEntries)>[
        (row) => OrderingTerm.asc(row.position),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  Future<void> close() => _database.close();

  PersistedMediaEntry _toDomain(MediaEntry row) {
    return PersistedMediaEntry(
      id: row.id,
      playlistId: row.playlistId,
      sourceReference: row.sourceReference,
      originalName: row.originalName,
      displayName: row.displayName,
      groupName: row.groupName,
      kind: MediaKind.values.byName(row.kind),
    );
  }
}
