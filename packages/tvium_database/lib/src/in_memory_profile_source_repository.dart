import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_epg/tvium_epg.dart';

import 'epg_repository.dart';
import 'persisted_media_entry.dart';
import 'profile_source_repository.dart';
import 'user_overlay_repository.dart';

final class InMemoryProfileSourceRepository
    implements
        ProfileSourceRepository,
        PagedProfileSourceRepository,
        EpgRepository,
        UserOverlayRepository {
  final _profiles = <String, UserProfile>{};
  final _sources = <String, IptvSource>{};
  final _links = <String, Set<String>>{};
  final _entries = <String, List<PersistedMediaEntry>>{};
  final _epgProgrammes = <String, List<EpgProgramme>>{};
  final _epgLinks = <String, EpgChannelLink>{};
  final _favorites = <MediaLocator>{};
  final _history = <MediaLocator, PlaybackHistoryEntry>{};
  final _parentalPolicies = <String, ParentalPolicy>{};
  String? _active;
  @override
  Future<UserProfile> ensureDefaultProfile() async {
    if (_profiles.isEmpty) await createProfile('Home');
    _active ??= _profiles.keys.first;
    return activeProfile();
  }

  @override
  Future<List<UserProfile>> profiles() async => _profiles.values.toList();
  @override
  Future<UserProfile> activeProfile() async =>
      _profiles[_active] ?? await ensureDefaultProfile();
  @override
  Future<UserProfile> createProfile(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        _profiles.values.any(
          (p) => p.displayName.toLowerCase() == trimmed.toLowerCase(),
        )) {
      throw ArgumentError('Choose a unique profile name.');
    }
    final profile = UserProfile('profile-${_profiles.length + 1}', trimmed);
    _profiles[profile.id] = profile;
    _active ??= profile.id;
    return profile;
  }

  @override
  Future<void> renameProfile(String id, String name) async {
    final trimmed = name.trim();
    if (!_profiles.containsKey(id) ||
        trimmed.isEmpty ||
        trimmed.length > 80 ||
        _profiles.values.any(
          (profile) =>
              profile.id != id &&
              profile.displayName.toLowerCase() == trimmed.toLowerCase(),
        )) {
      throw ArgumentError('Choose a unique profile name.');
    }
    _profiles[id] = UserProfile(id, trimmed);
  }

  @override
  Future<List<IptvSource>> deleteProfile(String id) async {
    if (!_profiles.containsKey(id) || _profiles.length <= 1) {
      throw ArgumentError('At least one profile is required.');
    }
    final linked = List<String>.of(_links[id] ?? const <String>{});
    _links.remove(id);
    _profiles.remove(id);
    _favorites.removeWhere((media) => media.profileId == id);
    _history.removeWhere((media, _) => media.profileId == id);
    _parentalPolicies.remove(id);
    if (_active == id) _active = _profiles.keys.first;
    final removed = <IptvSource>[];
    for (final sourceId in linked) {
      if (_links.values.any((ids) => ids.contains(sourceId))) continue;
      final source = _sources.remove(sourceId);
      _entries.remove(sourceId);
      if (source != null) removed.add(source);
    }
    return removed;
  }

  @override
  Future<void> setActiveProfile(String id) async {
    if (!_profiles.containsKey(id)) {
      throw ArgumentError('Unknown profile.');
    }
    _active = id;
  }

  @override
  Future<IptvSource?> sourceByIdentity(String digest) async {
    for (final source in _sources.values) {
      if (source.identityDigest == digest) return source;
    }
    return null;
  }

  @override
  Future<List<IptvSource>> sourcesForProfile(String profileId) async =>
      (_links[profileId] ?? {}).map((id) => _sources[id]!).toList();
  @override
  Future<List<PersistedMediaEntry>> entriesForPlaylist(String sourceId) async =>
      List.of(_entries[sourceId] ?? []);
  @override
  Future<int> countEntriesForPlaylist(String sourceId, MediaKind kind) async =>
      (_entries[sourceId] ?? []).where((entry) => entry.kind == kind).length;
  @override
  Future<List<PersistedMediaEntry>> entriesPageForPlaylist(
    String sourceId,
    MediaKind kind, {
    required int offset,
    required int limit,
  }) async {
    if (offset < 0 || limit < 1 || limit > 500) {
      throw ArgumentError('Invalid catalog page.');
    }
    return (_entries[sourceId] ?? [])
        .where((entry) => entry.kind == kind)
        .skip(offset)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> registerSource(
    IptvSource source,
    String profileId,
    List<PersistedMediaEntry> entries,
  ) async {
    if (!_profiles.containsKey(profileId)) {
      throw ArgumentError('Invalid source registration.');
    }
    final existing = await sourceByIdentity(source.identityDigest);
    if (existing != null && existing.id != source.id) {
      await linkSource(profileId, existing.id);
      return;
    }
    if (entries.any((entry) => entry.playlistId != source.id)) {
      throw ArgumentError('Invalid source registration.');
    }
    _sources[source.id] = source;
    _entries[source.id] = List.of(entries);
    await linkSource(profileId, source.id);
  }

  @override
  Future<void> linkSource(String profileId, String sourceId) async {
    if (!_profiles.containsKey(profileId) || !_sources.containsKey(sourceId)) {
      throw ArgumentError('Unknown profile or source.');
    }
    (_links[profileId] ??= {}).add(sourceId);
  }

  @override
  Future<void> renameSource(String sourceId, String name) async {
    final source = _sources[sourceId];
    final trimmed = name.trim();
    if (source == null || trimmed.isEmpty || trimmed.length > 120) {
      throw ArgumentError('Choose a valid source name.');
    }
    _sources[sourceId] = IptvSource(
      id: source.id,
      displayName: trimmed,
      identityDigest: source.identityDigest,
      secretReference: source.secretReference,
    );
  }

  @override
  Future<IptvSource?> unlinkSource(String profileId, String sourceId) async {
    final links = _links[profileId];
    if (links == null || !links.remove(sourceId)) {
      throw ArgumentError('Unknown profile source.');
    }
    if (_links.values.any((ids) => ids.contains(sourceId))) return null;
    final source = _sources.remove(sourceId);
    _entries.remove(sourceId);
    _favorites.removeWhere((media) => media.sourceId == sourceId);
    _history.removeWhere((media, _) => media.sourceId == sourceId);
    return source;
  }

  @override
  Future<void> replaceEpg({
    required String epgSourceId,
    required Iterable<EpgChannel> channels,
    required Iterable<EpgProgramme> programmes,
    required Iterable<EpgChannelLink> links,
  }) async {
    final availableIds = channels.map((channel) => channel.id).toSet();
    final replacement = programmes.toList(growable: false);
    if (replacement.any(
      (programme) =>
          !availableIds.contains(programme.channelId) ||
          !programme.stopUtc.isAfter(programme.startUtc),
    )) {
      throw ArgumentError('Invalid programme guide replacement.');
    }
    final replacementLinks = links.toList(growable: false);
    if (replacementLinks.any(
      (link) =>
          link.epgSourceId != epgSourceId ||
          !availableIds.contains(link.xmltvChannelId),
    )) {
      throw ArgumentError('Invalid programme guide links.');
    }
    _epgProgrammes[epgSourceId] = replacement;
    _epgLinks.removeWhere((_, link) => link.epgSourceId == epgSourceId);
    for (final link in replacementLinks) {
      _epgLinks[link.appChannelId] = link;
    }
  }

  @override
  Future<EpgNowNext> nowNextForChannel(
    String appChannelId,
    DateTime atUtc,
  ) async {
    final link = _epgLinks[appChannelId];
    if (link == null) return const EpgNowNext();
    final at = atUtc.toUtc();
    final programmes =
        (_epgProgrammes[link.epgSourceId] ?? const [])
            .where((programme) => programme.channelId == link.xmltvChannelId)
            .toList(growable: false)
          ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    EpgProgramme? current;
    EpgProgramme? next;
    for (final programme in programmes) {
      if (!programme.startUtc.isAfter(at) && programme.stopUtc.isAfter(at)) {
        current ??= programme;
      } else if (!programme.startUtc.isBefore(at)) {
        next ??= programme;
      }
    }
    return EpgNowNext(current: current, next: next);
  }

  @override
  Future<List<EpgProgramme>> searchProgrammes({
    required String query,
    required DateTime fromUtc,
    required DateTime toUtc,
    int limit = 50,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty || limit <= 0) return const [];
    final matches =
        _epgProgrammes.values
            .expand((programmes) => programmes)
            .where(
              (programme) =>
                  programme.stopUtc.isAfter(fromUtc.toUtc()) &&
                  programme.startUtc.isBefore(toUtc.toUtc()) &&
                  '${programme.title} ${programme.subtitle ?? ''} ${programme.description ?? ''}'
                      .toLowerCase()
                      .contains(normalized),
            )
            .toList(growable: false)
          ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return matches.take(limit).toList(growable: false);
  }

  @override
  Future<int> pruneEpgBefore(DateTime cutoffUtc) async {
    var removed = 0;
    for (final entry in _epgProgrammes.entries) {
      final retained = entry.value
          .where((programme) => programme.stopUtc.isAfter(cutoffUtc.toUtc()))
          .toList(growable: false);
      removed += entry.value.length - retained.length;
      _epgProgrammes[entry.key] = retained;
    }
    return removed;
  }

  @override
  Future<void> setFavorite(
    MediaLocator media, {
    required bool isFavorite,
  }) async {
    if (isFavorite) {
      _favorites.add(media);
    } else {
      _favorites.remove(media);
    }
  }

  @override
  Future<bool> isFavorite(MediaLocator media) async =>
      _favorites.contains(media);

  @override
  Future<List<MediaLocator>> favoritesForProfile(String profileId) async =>
      _favorites
          .where((favorite) => favorite.profileId == profileId)
          .toList(growable: false);

  @override
  Future<void> recordPlayback(PlaybackHistoryEntry entry) async {
    _history[entry.media] = entry;
  }

  @override
  Future<List<PlaybackHistoryEntry>> historyForProfile(
    String profileId, {
    int limit = 100,
  }) async {
    if (limit <= 0) return const [];
    final result =
        _history.values
            .where((entry) => entry.media.profileId == profileId)
            .toList(growable: false)
          ..sort((a, b) => b.lastPlayedAtUtc.compareTo(a.lastPlayedAtUtc));
    return result.take(limit).toList(growable: false);
  }

  @override
  Future<void> clearHistory(String profileId) async {
    _history.removeWhere((media, _) => media.profileId == profileId);
  }

  @override
  Future<void> saveParentalPolicy(ParentalPolicy policy) async {
    _parentalPolicies[policy.profileId] = policy;
  }

  @override
  Future<ParentalPolicy?> parentalPolicyForProfile(String profileId) async =>
      _parentalPolicies[profileId];

  @override
  Future<void> close() async {
    _epgProgrammes.clear();
    _epgLinks.clear();
    _favorites.clear();
    _history.clear();
    _parentalPolicies.clear();
  }
}
