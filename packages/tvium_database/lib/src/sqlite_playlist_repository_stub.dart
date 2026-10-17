import 'package:tvium_epg/tvium_epg.dart';

import 'epg_repository.dart';
import 'persisted_media_entry.dart';
import 'playlist_repository.dart';
import 'profile_source_repository.dart';
import 'user_overlay_repository.dart';

final class SqlitePlaylistRepository
    implements
        PlaylistRepository,
        ProfileSourceRepository,
        EpgRepository,
        UserOverlayRepository {
  factory SqlitePlaylistRepository.open(String path) {
    throw UnsupportedError(
      'SQLite file persistence is unavailable on this platform.',
    );
  }

  Never _unsupported() => throw UnsupportedError(
    'SQLite file persistence is unavailable on this platform.',
  );

  @override
  Future<UserProfile> activeProfile() => _unsupported();

  @override
  Future<UserProfile> createProfile(String name) => _unsupported();

  @override
  Future<UserProfile> ensureDefaultProfile() => _unsupported();

  @override
  Future<List<UserProfile>> profiles() => _unsupported();

  @override
  Future<void> setActiveProfile(String id) => _unsupported();

  @override
  Future<IptvSource?> sourceByIdentity(String digest) => _unsupported();

  @override
  Future<List<IptvSource>> sourcesForProfile(String profileId) =>
      _unsupported();

  @override
  Future<void> registerSource(
    IptvSource source,
    String profileId,
    List<PersistedMediaEntry> entries,
  ) => _unsupported();

  @override
  Future<void> linkSource(String profileId, String sourceId) => _unsupported();

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

  @override
  Future<void> close() async {}

  @override
  Future<void> setFavorite(MediaLocator media, {required bool isFavorite}) =>
      _unsupported();

  @override
  Future<bool> isFavorite(MediaLocator media) => _unsupported();

  @override
  Future<List<MediaLocator>> favoritesForProfile(String profileId) =>
      _unsupported();

  @override
  Future<void> recordPlayback(PlaybackHistoryEntry entry) => _unsupported();

  @override
  Future<List<PlaybackHistoryEntry>> historyForProfile(
    String profileId, {
    int limit = 100,
  }) => _unsupported();

  @override
  Future<void> clearHistory(String profileId) => _unsupported();

  @override
  Future<void> saveParentalPolicy(ParentalPolicy policy) => _unsupported();

  @override
  Future<ParentalPolicy?> parentalPolicyForProfile(String profileId) =>
      _unsupported();

  @override
  Future<EpgNowNext> nowNextForChannel(String appChannelId, DateTime atUtc) =>
      _unsupported();

  @override
  Future<int> pruneEpgBefore(DateTime cutoffUtc) => _unsupported();

  @override
  Future<void> replaceEpg({
    required String epgSourceId,
    required Iterable<EpgChannel> channels,
    required Iterable<EpgProgramme> programmes,
    required Iterable<EpgChannelLink> links,
  }) => _unsupported();

  @override
  Future<List<EpgProgramme>> searchProgrammes({
    required String query,
    required DateTime fromUtc,
    required DateTime toUtc,
    int limit = 50,
  }) => _unsupported();
}
