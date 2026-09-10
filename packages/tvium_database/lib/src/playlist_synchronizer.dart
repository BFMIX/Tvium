import 'persisted_media_entry.dart';
import 'playlist_diff.dart';
import 'playlist_repository.dart';

final class PlaylistSynchronizer {
  const PlaylistSynchronizer(this._repository);

  final PlaylistRepository _repository;

  Future<PlaylistDiff> refresh(
    String playlistId,
    Iterable<PersistedMediaEntry> incoming,
  ) async {
    final replacement = incoming.toList(growable: false);
    final previous = await _repository.entriesForPlaylist(playlistId);
    final diff = PlaylistDiff.calculate(
      previous: previous,
      incoming: replacement,
    );
    await _repository.replaceEntries(playlistId, replacement);
    return diff;
  }
}
