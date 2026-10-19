import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_epg/tvium_epg.dart';

import '../library/library_bootstrap_controller.dart';

final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  final repository = ref.watch(libraryRepositoryProvider).value;
  if (repository case final EpgRepository epgRepository) {
    return epgRepository;
  }
  return const _UnavailableEpgRepository();
});

final class EpgNowNextRequest {
  EpgNowNextRequest({
    required this.profileId,
    required this.sourceId,
    required List<PersistedMediaEntry> entries,
    required DateTime atUtc,
  }) : entries = List<PersistedMediaEntry>.unmodifiable(entries),
       atUtc = atUtc.toUtc();

  final String profileId;
  final String sourceId;
  final List<PersistedMediaEntry> entries;
  final DateTime atUtc;

  @override
  bool operator ==(Object other) =>
      other is EpgNowNextRequest &&
      other.profileId == profileId &&
      other.sourceId == sourceId &&
      other.atUtc == atUtc &&
      _entryKey(other.entries) == _entryKey(entries);

  @override
  int get hashCode =>
      Object.hash(profileId, sourceId, atUtc, _entryKey(entries));

  static String _entryKey(List<PersistedMediaEntry> values) => values
      .map(
        (entry) => '${entry.id}:${entry.kind.name}:${entry.epgChannelId ?? ''}',
      )
      .join('|');
}

final class EpgNowNextSnapshot {
  EpgNowNextSnapshot({
    required this.profileId,
    required this.sourceId,
    required Map<String, EpgNowNext?> schedules,
  }) : _schedules = Map<String, EpgNowNext?>.unmodifiable(schedules);

  final String profileId;
  final String sourceId;
  final Map<String, EpgNowNext?> _schedules;

  bool containsEntry(String entryId) => _schedules.containsKey(entryId);

  EpgNowNext? forEntry(String entryId) => _schedules[entryId];
}

final epgNowNextProvider =
    FutureProvider.family<EpgNowNextSnapshot, EpgNowNextRequest>((
      ref,
      request,
    ) async {
      final repository = ref.watch(epgRepositoryProvider);
      final schedules = <String, EpgNowNext?>{};
      for (final entry in request.entries) {
        if (entry.playlistId != request.sourceId ||
            entry.kind != MediaKind.live ||
            entry.epgChannelId == null ||
            entry.epgChannelId!.isEmpty) {
          continue;
        }
        final value = await repository.nowNextForChannel(
          entry.id,
          request.atUtc,
        );
        schedules[entry.id] = value.current == null && value.next == null
            ? null
            : value;
      }
      return EpgNowNextSnapshot(
        profileId: request.profileId,
        sourceId: request.sourceId,
        schedules: schedules,
      );
    });

final class _UnavailableEpgRepository implements EpgRepository {
  const _UnavailableEpgRepository();

  @override
  Future<EpgNowNext> nowNextForChannel(
    String appChannelId,
    DateTime atUtc,
  ) async => const EpgNowNext();

  @override
  Future<int> pruneEpgBefore(DateTime cutoffUtc) async => 0;

  @override
  Future<void> replaceEpg({
    required String epgSourceId,
    required Iterable<EpgChannel> channels,
    required Iterable<EpgProgramme> programmes,
    required Iterable<EpgChannelLink> links,
  }) => throw UnsupportedError('EPG persistence is unavailable.');

  @override
  Future<List<EpgProgramme>> searchProgrammes({
    required String query,
    required DateTime fromUtc,
    required DateTime toUtc,
    int limit = 50,
  }) async => const [];
}
