final class MediaLocator {
  const MediaLocator({
    required this.profileId,
    required this.sourceId,
    required this.entryId,
  });

  final String profileId;
  final String sourceId;
  final String entryId;

  @override
  bool operator ==(Object other) =>
      other is MediaLocator &&
      profileId == other.profileId &&
      sourceId == other.sourceId &&
      entryId == other.entryId;

  @override
  int get hashCode => Object.hash(profileId, sourceId, entryId);
}

final class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.media,
    required this.lastPlayedAtUtc,
    required this.position,
    required this.duration,
  });

  final MediaLocator media;
  final DateTime lastPlayedAtUtc;
  final Duration position;
  final Duration duration;
}

final class ParentalPolicy {
  const ParentalPolicy({
    required this.profileId,
    required this.pinDigest,
    required this.blockedContent,
  });

  final String profileId;
  final String pinDigest;
  final Set<String> blockedContent;
}

abstract interface class UserOverlayRepository {
  Future<void> setFavorite(MediaLocator media, {required bool isFavorite});
  Future<bool> isFavorite(MediaLocator media);
  Future<List<MediaLocator>> favoritesForProfile(String profileId);
  Future<void> recordPlayback(PlaybackHistoryEntry entry);
  Future<List<PlaybackHistoryEntry>> historyForProfile(
    String profileId, {
    int limit = 100,
  });
  Future<void> clearHistory(String profileId);
  Future<void> saveParentalPolicy(ParentalPolicy policy);
  Future<ParentalPolicy?> parentalPolicyForProfile(String profileId);
  Future<void> close();
}
