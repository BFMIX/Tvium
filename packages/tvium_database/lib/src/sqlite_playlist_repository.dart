import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_epg/tvium_epg.dart';

import 'epg_repository.dart';
import 'persisted_media_entry.dart';
import 'playlist_repository.dart';
import 'profile_source_repository.dart';
import 'tvium_database.dart';
import 'user_overlay_repository.dart';

final class SqlitePlaylistRepository
    implements
        PlaylistRepository,
        ProfileSourceRepository,
        EpgRepository,
        UserOverlayRepository {
  SqlitePlaylistRepository._(this._database);

  factory SqlitePlaylistRepository.open(String path) {
    return SqlitePlaylistRepository._(
      TviumDatabase(NativeDatabase(File(path))),
    );
  }

  final TviumDatabase _database;

  String _id() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  @override
  Future<List<UserProfile>> profiles() async =>
      (await _database
              .customSelect('SELECT id,name FROM user_profiles ORDER BY rowid')
              .get())
          .map((r) => UserProfile(r.read<String>('id'), r.read<String>('name')))
          .toList();

  @override
  Future<UserProfile> ensureDefaultProfile() => _database.transaction(() async {
    if ((await profiles()).isEmpty) {
      await createProfile('Home');
    }
    return activeProfile();
  });

  @override
  Future<UserProfile> activeProfile() async {
    final available = await profiles();
    if (available.isEmpty) {
      return ensureDefaultProfile();
    }
    final selected = await _database
        .customSelect(
          "SELECT value FROM app_settings WHERE key='activeProfileId'",
        )
        .getSingleOrNull();
    return available.firstWhere(
      (p) => p.id == selected?.read<String>('value'),
      orElse: () => available.first,
    );
  }

  @override
  Future<UserProfile> createProfile(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 80 ||
        (await profiles()).any(
          (p) => p.displayName.toLowerCase() == trimmed.toLowerCase(),
        )) {
      throw ArgumentError('Choose a unique profile name.');
    }
    final profile = UserProfile(_id(), trimmed);
    await _database.customStatement(
      'INSERT INTO user_profiles(id,name) VALUES (?,?)',
      [profile.id, profile.displayName],
    );
    return profile;
  }

  @override
  Future<void> renameProfile(String id, String name) async {
    final trimmed = name.trim();
    final available = await profiles();
    if (trimmed.isEmpty ||
        trimmed.length > 80 ||
        !available.any((profile) => profile.id == id) ||
        available.any(
          (profile) =>
              profile.id != id &&
              profile.displayName.toLowerCase() == trimmed.toLowerCase(),
        )) {
      throw ArgumentError('Choose a unique profile name.');
    }
    await _database.customStatement(
      'UPDATE user_profiles SET name=? WHERE id=?',
      [trimmed, id],
    );
  }

  @override
  Future<List<IptvSource>> deleteProfile(String id) async {
    final available = await profiles();
    if (available.length <= 1 ||
        !available.any((profile) => profile.id == id)) {
      throw ArgumentError('At least one profile is required.');
    }
    return _database.transaction(() async {
      final linked = await sourcesForProfile(id);
      await _database.customStatement(
        'DELETE FROM favorites WHERE profile_id=?',
        [id],
      );
      await _database.customStatement(
        'DELETE FROM playback_history WHERE profile_id=?',
        [id],
      );
      await _database.customStatement(
        'DELETE FROM parental_policies WHERE profile_id=?',
        [id],
      );
      await _database.customStatement(
        'DELETE FROM profile_sources WHERE profile_id=?',
        [id],
      );
      await _database.customStatement('DELETE FROM user_profiles WHERE id=?', [
        id,
      ]);
      final selected = await activeProfile();
      await setActiveProfile(selected.id);
      final removed = <IptvSource>[];
      for (final source in linked) {
        final deleted = await _deleteSourceIfOrphan(source.id);
        if (deleted != null) removed.add(deleted);
      }
      return removed;
    });
  }

  @override
  Future<void> setActiveProfile(String id) async {
    if (!(await profiles()).any((p) => p.id == id)) {
      throw ArgumentError('Unknown profile.');
    }
    await _database.customStatement(
      "INSERT OR REPLACE INTO app_settings(key,value) VALUES ('activeProfileId',?)",
      [id],
    );
  }

  IptvSource _source(QueryRow r) => IptvSource(
    id: r.read<String>('id'),
    displayName: r.read<String>('name'),
    identityDigest: r.read<String>('digest'),
    secretReference: r.read<String>('secret_reference'),
  );

  @override
  Future<IptvSource?> sourceByIdentity(String digest) async {
    final row = await _database
        .customSelect(
          'SELECT * FROM iptv_sources WHERE digest=?',
          variables: [Variable.withString(digest)],
        )
        .getSingleOrNull();
    return row == null ? null : _source(row);
  }

  @override
  Future<List<IptvSource>> sourcesForProfile(String profileId) async =>
      (await _database
              .customSelect(
                'SELECT s.* FROM iptv_sources s JOIN profile_sources p ON p.source_id=s.id WHERE p.profile_id=? ORDER BY p.rowid',
                variables: [Variable.withString(profileId)],
              )
              .get())
          .map(_source)
          .toList();

  @override
  Future<void> linkSource(String profileId, String sourceId) async {
    final profile = await _database
        .customSelect(
          'SELECT id FROM user_profiles WHERE id=?',
          variables: [Variable.withString(profileId)],
        )
        .getSingleOrNull();
    final source = await _database
        .customSelect(
          'SELECT id FROM iptv_sources WHERE id=?',
          variables: [Variable.withString(sourceId)],
        )
        .getSingleOrNull();
    if (profile == null || source == null) {
      throw ArgumentError('Unknown profile or source.');
    }
    await _database.customStatement(
      'INSERT OR IGNORE INTO profile_sources(profile_id,source_id) VALUES (?,?)',
      [profileId, sourceId],
    );
  }

  @override
  Future<void> renameSource(String sourceId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 120) {
      throw ArgumentError('Choose a valid source name.');
    }
    final updated = await _database.customUpdate(
      'UPDATE iptv_sources SET name=? WHERE id=?',
      variables: [Variable.withString(trimmed), Variable.withString(sourceId)],
      updates: const {},
    );
    if (updated == 0) throw ArgumentError('Unknown source.');
  }

  @override
  Future<IptvSource?> unlinkSource(String profileId, String sourceId) =>
      _database.transaction(() async {
        final removed = await _database.customUpdate(
          'DELETE FROM profile_sources WHERE profile_id=? AND source_id=?',
          variables: [
            Variable.withString(profileId),
            Variable.withString(sourceId),
          ],
          updates: const {},
        );
        if (removed == 0) throw ArgumentError('Unknown profile source.');
        return _deleteSourceIfOrphan(sourceId);
      });

  Future<IptvSource?> _deleteSourceIfOrphan(String sourceId) async {
    final linked = await _database
        .customSelect(
          'SELECT 1 FROM profile_sources WHERE source_id=? LIMIT 1',
          variables: [Variable.withString(sourceId)],
        )
        .getSingleOrNull();
    if (linked != null) return null;
    final row = await _database
        .customSelect(
          'SELECT * FROM iptv_sources WHERE id=?',
          variables: [Variable.withString(sourceId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final source = _source(row);
    await _database.customStatement('DELETE FROM favorites WHERE source_id=?', [
      sourceId,
    ]);
    await _database.customStatement(
      'DELETE FROM playback_history WHERE source_id=?',
      [sourceId],
    );
    await _database.customStatement(
      'DELETE FROM media_entries WHERE playlist_id=?',
      [sourceId],
    );
    await _database.customStatement(
      'DELETE FROM catalog_details WHERE source_id=?',
      [sourceId],
    );
    await _database.customStatement(
      'DELETE FROM epg_channel_links WHERE source_id=?',
      [sourceId],
    );
    await _database.customStatement(
      'DELETE FROM epg_programmes WHERE source_id=?',
      [sourceId],
    );
    await _database.customStatement(
      'DELETE FROM epg_channels WHERE source_id=?',
      [sourceId],
    );
    await _database.customStatement('DELETE FROM iptv_sources WHERE id=?', [
      sourceId,
    ]);
    return source;
  }

  @override
  Future<void> registerSource(
    IptvSource source,
    String profileId,
    List<PersistedMediaEntry> entries,
  ) => _database.transaction(() async {
    final existing = await sourceByIdentity(source.identityDigest);
    if (existing != null && existing.id != source.id) {
      await linkSource(profileId, existing.id);
      return;
    }
    await _database.customStatement(
      'INSERT INTO iptv_sources(id,name,digest,secret_reference) VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,digest=excluded.digest,secret_reference=excluded.secret_reference',
      [
        source.id,
        source.displayName,
        source.identityDigest,
        source.secretReference,
      ],
    );
    await linkSource(profileId, source.id);
    await replaceEntries(source.id, entries);
  });

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
      await _database.customStatement(
        'DELETE FROM catalog_details WHERE source_id=?',
        [playlistId],
      );
      for (final entry in replacement) {
        await _database.customStatement(
          'INSERT INTO catalog_details('
          'source_id,entry_id,external_id,extension,epg_channel_id) '
          'VALUES (?,?,?,?,?)',
          [
            playlistId,
            entry.id,
            entry.externalId,
            entry.containerExtension,
            entry.epgChannelId,
          ],
        );
      }
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
    final rows = await query.get();
    final byId = await _detailsForSource(playlistId);
    return rows
        .map((row) => _toDomain(row, byId[row.id]))
        .toList(growable: false);
  }

  @override
  Future<void> setFavorite(
    MediaLocator media, {
    required bool isFavorite,
  }) async {
    if (!isFavorite) {
      await _database.customStatement(
        'DELETE FROM favorites WHERE profile_id=? AND source_id=? AND entry_id=?',
        [media.profileId, media.sourceId, media.entryId],
      );
      return;
    }
    await _database.customStatement(
      'INSERT OR IGNORE INTO favorites('
      'profile_id,source_id,entry_id,created_at_utc) VALUES (?,?,?,?)',
      [
        media.profileId,
        media.sourceId,
        media.entryId,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<bool> isFavorite(MediaLocator media) async =>
      await _database
          .customSelect(
            'SELECT 1 FROM favorites '
            'WHERE profile_id=? AND source_id=? AND entry_id=? LIMIT 1',
            variables: [
              Variable.withString(media.profileId),
              Variable.withString(media.sourceId),
              Variable.withString(media.entryId),
            ],
          )
          .getSingleOrNull() !=
      null;

  @override
  Future<List<MediaLocator>> favoritesForProfile(String profileId) async =>
      (await _database
              .customSelect(
                'SELECT profile_id,source_id,entry_id FROM favorites '
                'WHERE profile_id=? ORDER BY created_at_utc DESC,rowid DESC',
                variables: [Variable.withString(profileId)],
              )
              .get())
          .map(
            (row) => MediaLocator(
              profileId: row.read<String>('profile_id'),
              sourceId: row.read<String>('source_id'),
              entryId: row.read<String>('entry_id'),
            ),
          )
          .toList(growable: false);

  @override
  Future<void> recordPlayback(PlaybackHistoryEntry entry) async {
    await _database.customStatement(
      'INSERT INTO playback_history('
      'profile_id,source_id,entry_id,last_played_at_utc,position_ms,duration_ms) '
      'VALUES (?,?,?,?,?,?) ON CONFLICT(profile_id,source_id,entry_id) '
      'DO UPDATE SET last_played_at_utc=excluded.last_played_at_utc,'
      'position_ms=excluded.position_ms,duration_ms=excluded.duration_ms',
      [
        entry.media.profileId,
        entry.media.sourceId,
        entry.media.entryId,
        entry.lastPlayedAtUtc.toUtc().millisecondsSinceEpoch,
        entry.position.inMilliseconds,
        entry.duration.inMilliseconds,
      ],
    );
  }

  @override
  Future<List<PlaybackHistoryEntry>> historyForProfile(
    String profileId, {
    int limit = 100,
  }) async {
    if (limit <= 0) return const [];
    return (await _database
            .customSelect(
              'SELECT * FROM playback_history WHERE profile_id=? '
              'ORDER BY last_played_at_utc DESC LIMIT ?',
              variables: [
                Variable.withString(profileId),
                Variable.withInt(limit),
              ],
            )
            .get())
        .map(
          (row) => PlaybackHistoryEntry(
            media: MediaLocator(
              profileId: row.read<String>('profile_id'),
              sourceId: row.read<String>('source_id'),
              entryId: row.read<String>('entry_id'),
            ),
            lastPlayedAtUtc: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('last_played_at_utc'),
              isUtc: true,
            ),
            position: Duration(milliseconds: row.read<int>('position_ms')),
            duration: Duration(milliseconds: row.read<int>('duration_ms')),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> clearHistory(String profileId) => _database.customStatement(
    'DELETE FROM playback_history WHERE profile_id=?',
    [profileId],
  );

  @override
  Future<void> saveParentalPolicy(ParentalPolicy policy) =>
      _database.customStatement(
        'INSERT INTO parental_policies('
        'profile_id,pin_digest,blocked_content_json) VALUES (?,?,?) '
        'ON CONFLICT(profile_id) DO UPDATE SET '
        'pin_digest=excluded.pin_digest,'
        'blocked_content_json=excluded.blocked_content_json',
        [
          policy.profileId,
          policy.pinDigest,
          jsonEncode(policy.blockedContent.toList(growable: false)..sort()),
        ],
      );

  @override
  Future<ParentalPolicy?> parentalPolicyForProfile(String profileId) async {
    final row = await _database
        .customSelect(
          'SELECT * FROM parental_policies WHERE profile_id=?',
          variables: [Variable.withString(profileId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return ParentalPolicy(
      profileId: row.read<String>('profile_id'),
      pinDigest: row.read<String>('pin_digest'),
      blockedContent: (jsonDecode(
        row.read<String>('blocked_content_json'),
      ) as List<dynamic>).cast<String>().toSet(),
    );
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
    final byId = await _detailsForSource(playlistId);
    return (await query.get())
        .map((row) => _toDomain(row, byId[row.id]))
        .toList(growable: false);
  }

  @override
  Future<void> close() => _database.close();

  @override
  Future<void> replaceEpg({
    required String epgSourceId,
    required Iterable<EpgChannel> channels,
    required Iterable<EpgProgramme> programmes,
    required Iterable<EpgChannelLink> links,
  }) async {
    final sourceId = epgSourceId.trim();
    final channelList = channels.toList(growable: false);
    final programmeList = programmes.toList(growable: false);
    final linkList = links.toList(growable: false);
    final channelIds = channelList.map((channel) => channel.id).toSet();
    if (sourceId.isEmpty || channelIds.length != channelList.length) {
      throw ArgumentError('EPG source and channel identifiers must be unique.');
    }
    if (channelList.any(
          (channel) =>
              channel.id.trim().isEmpty || channel.displayName.trim().isEmpty,
        ) ||
        programmeList.any(
          (programme) =>
              !channelIds.contains(programme.channelId) ||
              programme.title.trim().isEmpty ||
              !programme.stopUtc.isAfter(programme.startUtc),
        ) ||
        linkList.any(
          (link) =>
              link.appChannelId.trim().isEmpty ||
              link.epgSourceId != sourceId ||
              !channelIds.contains(link.xmltvChannelId),
        )) {
      throw ArgumentError('EPG replacement contains invalid records.');
    }
    if (linkList.map((link) => link.appChannelId).toSet().length !=
        linkList.length) {
      throw ArgumentError('EPG channel links must be unique.');
    }

    await _database.transaction(() async {
      await _database.customStatement(
        'DELETE FROM epg_channel_links WHERE source_id=?',
        [sourceId],
      );
      await _database.customStatement(
        'DELETE FROM epg_programmes WHERE source_id=?',
        [sourceId],
      );
      await _database.customStatement(
        'DELETE FROM epg_channels WHERE source_id=?',
        [sourceId],
      );
      for (final channel in channelList) {
        await _database.customStatement(
          'INSERT INTO epg_channels(source_id,channel_id,display_name) '
          'VALUES (?,?,?)',
          [sourceId, channel.id, channel.displayName],
        );
      }
      for (final programme in programmeList) {
        await _database.customStatement(
          'INSERT INTO epg_programmes('
          'source_id,channel_id,start_utc,stop_utc,title,title_search,'
          'subtitle,description,categories_json) VALUES (?,?,?,?,?,?,?,?,?)',
          [
            sourceId,
            programme.channelId,
            programme.startUtc.toUtc().millisecondsSinceEpoch,
            programme.stopUtc.toUtc().millisecondsSinceEpoch,
            programme.title,
            programme.title.toLowerCase(),
            programme.subtitle,
            programme.description,
            jsonEncode(programme.categories),
          ],
        );
      }
      for (final link in linkList) {
        await _database.customStatement(
          'INSERT INTO epg_channel_links('
          'app_channel_id,source_id,channel_id,strategy) VALUES (?,?,?,?) '
          'ON CONFLICT(app_channel_id) DO UPDATE SET '
          'source_id=excluded.source_id,channel_id=excluded.channel_id,'
          'strategy=excluded.strategy',
          [
            link.appChannelId,
            sourceId,
            link.xmltvChannelId,
            link.strategy.name,
          ],
        );
      }
    });
  }

  @override
  Future<EpgNowNext> nowNextForChannel(
    String appChannelId,
    DateTime atUtc,
  ) async {
    final instant = atUtc.toUtc().millisecondsSinceEpoch;
    final rows = await _database
        .customSelect(
          '''
          WITH selected_link AS (
            SELECT source_id, channel_id
            FROM epg_channel_links
            WHERE app_channel_id = ?
          ), current_programme AS (
            SELECT p.*
            FROM epg_programmes p
            JOIN selected_link l
              ON l.source_id = p.source_id AND l.channel_id = p.channel_id
            WHERE p.start_utc <= ? AND p.stop_utc > ?
            ORDER BY p.start_utc DESC, p.stop_utc ASC, p.title ASC
            LIMIT 1
          ), next_programme AS (
            SELECT p.*
            FROM epg_programmes p
            JOIN selected_link l
              ON l.source_id = p.source_id AND l.channel_id = p.channel_id
            WHERE p.start_utc >= COALESCE(
              (SELECT stop_utc FROM current_programme), ?
            )
            ORDER BY p.start_utc ASC, p.stop_utc ASC, p.title ASC
            LIMIT 1
          )
          SELECT 'current' AS slot, current_programme.*
          FROM current_programme
          UNION ALL
          SELECT 'next' AS slot, next_programme.*
          FROM next_programme
          ''',
          variables: [
            Variable.withString(appChannelId),
            Variable.withInt(instant),
            Variable.withInt(instant),
            Variable.withInt(instant),
          ],
        )
        .get();
    final bySlot = {for (final row in rows) row.read<String>('slot'): row};
    final currentRow = bySlot['current'];
    final nextRow = bySlot['next'];
    return EpgNowNext(
      current: currentRow == null ? null : _programme(currentRow),
      next: nextRow == null ? null : _programme(nextRow),
    );
  }

  @override
  Future<List<EpgProgramme>> searchProgrammes({
    required String query,
    required DateTime fromUtc,
    required DateTime toUtc,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200 || !toUtc.isAfter(fromUtc)) {
      throw ArgumentError('Use a valid time range and a limit from 1 to 200.');
    }
    final normalizedQuery = query.trim().toLowerCase();
    final escapedQuery = normalizedQuery
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await _database
        .customSelect(
          'SELECT * FROM epg_programmes '
          "WHERE title_search LIKE ? ESCAPE '\\' "
          'AND stop_utc>? AND start_utc<? '
          'ORDER BY start_utc ASC,stop_utc ASC,title ASC,'
          'source_id ASC,channel_id ASC LIMIT ?',
          variables: [
            Variable.withString('%$escapedQuery%'),
            Variable.withInt(fromUtc.toUtc().millisecondsSinceEpoch),
            Variable.withInt(toUtc.toUtc().millisecondsSinceEpoch),
            Variable.withInt(limit),
          ],
        )
        .get();
    return rows.map(_programme).toList(growable: false);
  }

  @override
  Future<int> pruneEpgBefore(DateTime cutoffUtc) => _database.customUpdate(
    'DELETE FROM epg_programmes WHERE stop_utc<=?',
    variables: [Variable.withInt(cutoffUtc.toUtc().millisecondsSinceEpoch)],
    updates: {_database.mediaEntries},
  );

  EpgProgramme _programme(QueryRow row) => EpgProgramme(
    channelId: row.read<String>('channel_id'),
    startUtc: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('start_utc'),
      isUtc: true,
    ),
    stopUtc: DateTime.fromMillisecondsSinceEpoch(
      row.read<int>('stop_utc'),
      isUtc: true,
    ),
    title: row.read<String>('title'),
    subtitle: row.readNullable<String>('subtitle'),
    description: row.readNullable<String>('description'),
    categories: (jsonDecode(row.read<String>('categories_json')) as List)
        .cast<String>(),
  );

  Future<Map<String, QueryRow>> _detailsForSource(String sourceId) async {
    final details = await _database
        .customSelect(
          'SELECT * FROM catalog_details WHERE source_id=?',
          variables: [Variable.withString(sourceId)],
        )
        .get();
    return {
      for (final detail in details) detail.read<String>('entry_id'): detail,
    };
  }

  PersistedMediaEntry _toDomain(MediaEntry row, [QueryRow? detail]) {
    return PersistedMediaEntry(
      id: row.id,
      playlistId: row.playlistId,
      sourceReference: row.sourceReference,
      originalName: row.originalName,
      displayName: row.displayName,
      groupName: row.groupName,
      kind: MediaKind.values.byName(row.kind),
      externalId: detail?.readNullable<String>('external_id'),
      containerExtension: detail?.readNullable<String>('extension'),
      epgChannelId: detail?.readNullable<String>('epg_channel_id'),
    );
  }
}
