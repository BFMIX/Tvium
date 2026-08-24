import 'persisted_media_entry.dart';

/// Persistence boundary used by imports and virtualized library screens.
abstract interface class PlaylistRepository {
  Future<void> replaceEntries(
    String playlistId,
    Iterable<PersistedMediaEntry> entries,
  );

  Future<List<PersistedMediaEntry>> entriesForPlaylist(String playlistId);

  Future<List<PersistedMediaEntry>> entriesForGroup(
    String playlistId,
    String groupName,
  );
}
