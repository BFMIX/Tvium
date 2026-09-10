import 'persisted_media_entry.dart';
import 'playlist_repository.dart';

final class SqlitePlaylistRepository implements PlaylistRepository {
  factory SqlitePlaylistRepository.open(String path) {
    throw UnsupportedError(
      'SQLite file persistence is unavailable on this platform.',
    );
  }

  @override
  Future<List<PersistedMediaEntry>> entriesForGroup(
    String playlistId,
    String groupName,
  ) {
    throw UnsupportedError(
      'SQLite file persistence is unavailable on this platform.',
    );
  }

  @override
  Future<List<PersistedMediaEntry>> entriesForPlaylist(String playlistId) {
    throw UnsupportedError(
      'SQLite file persistence is unavailable on this platform.',
    );
  }

  @override
  Future<void> replaceEntries(
    String playlistId,
    Iterable<PersistedMediaEntry> entries,
  ) {
    throw UnsupportedError(
      'SQLite file persistence is unavailable on this platform.',
    );
  }

  Future<void> close() async {}
}
