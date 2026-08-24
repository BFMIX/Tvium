import 'dart:collection';

import 'persisted_media_entry.dart';
import 'playlist_repository.dart';

/// Deterministic Phase 0 implementation; native SQLite remains a later adapter.
final class InMemoryPlaylistRepository implements PlaylistRepository {
  final Map<String, List<PersistedMediaEntry>> _entriesByPlaylist =
      <String, List<PersistedMediaEntry>>{};

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
    _entriesByPlaylist[playlistId] = replacement;
  }

  @override
  Future<List<PersistedMediaEntry>> entriesForPlaylist(
    String playlistId,
  ) async {
    return UnmodifiableListView<PersistedMediaEntry>(
      _entriesByPlaylist[playlistId] ?? const <PersistedMediaEntry>[],
    );
  }

  @override
  Future<List<PersistedMediaEntry>> entriesForGroup(
    String playlistId,
    String groupName,
  ) async {
    final entries = _entriesByPlaylist[playlistId];
    if (entries == null) {
      return const <PersistedMediaEntry>[];
    }
    return UnmodifiableListView<PersistedMediaEntry>(
      entries.where((entry) => entry.groupName == groupName),
    );
  }
}
