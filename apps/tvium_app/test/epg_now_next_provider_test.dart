import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/epg/epg_now_next_provider.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_epg/tvium_epg.dart';

void main() {
  final instant = DateTime.utc(2026, 10, 16, 10, 30);

  test('loads schedules only for matched live entries in the source', () async {
    final repository = _RecordingEpgRepository({
      'live:news': EpgNowNext(
        current: EpgProgramme(
          channelId: 'guide.news',
          startUtc: DateTime.utc(2026, 10, 16, 10),
          stopUtc: DateTime.utc(2026, 10, 16, 11),
          title: 'Morning News',
        ),
        next: EpgProgramme(
          channelId: 'guide.news',
          startUtc: DateTime.utc(2026, 10, 16, 11),
          stopUtc: DateTime.utc(2026, 10, 16, 12),
          title: 'Daily Report',
        ),
      ),
    });
    final container = ProviderContainer(
      overrides: [epgRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(
      epgNowNextProvider(
        EpgNowNextRequest(
          profileId: 'profile-home',
          sourceId: 'source-a',
          entries: [
            _entry(
              id: 'live:news',
              sourceId: 'source-a',
              kind: MediaKind.live,
              epgChannelId: 'guide.news',
            ),
            _entry(
              id: 'live:unmatched',
              sourceId: 'source-a',
              kind: MediaKind.live,
            ),
            _entry(
              id: 'movie:news',
              sourceId: 'source-a',
              kind: MediaKind.movie,
              epgChannelId: 'guide.news',
            ),
            _entry(
              id: 'episode:news',
              sourceId: 'source-a',
              kind: MediaKind.episode,
              epgChannelId: 'guide.news',
            ),
            _entry(
              id: 'live:other-source',
              sourceId: 'source-b',
              kind: MediaKind.live,
              epgChannelId: 'guide.other',
            ),
          ],
          atUtc: instant,
        ),
      ).future,
    );

    expect(repository.lookups, [('live:news', instant)]);
    expect(snapshot.profileId, 'profile-home');
    expect(snapshot.sourceId, 'source-a');
    expect(snapshot.forEntry('live:news')?.current?.title, 'Morning News');
    expect(snapshot.forEntry('live:news')?.next?.title, 'Daily Report');
    expect(snapshot.forEntry('live:unmatched'), isNull);
    expect(snapshot.forEntry('movie:news'), isNull);
    expect(snapshot.forEntry('episode:news'), isNull);
  });

  test('represents a matched channel with no programme data as null', () async {
    final repository = _RecordingEpgRepository({
      'live:empty': const EpgNowNext(),
    });
    final container = ProviderContainer(
      overrides: [epgRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(
      epgNowNextProvider(
        EpgNowNextRequest(
          profileId: 'profile-home',
          sourceId: 'source-a',
          entries: [
            _entry(
              id: 'live:empty',
              sourceId: 'source-a',
              kind: MediaKind.live,
              epgChannelId: 'guide.empty',
            ),
          ],
          atUtc: instant,
        ),
      ).future,
    );

    expect(repository.lookups, [('live:empty', instant)]);
    expect(snapshot.containsEntry('live:empty'), isTrue);
    expect(snapshot.forEntry('live:empty'), isNull);
  });

  test('a new profile and source request produces a fresh snapshot', () async {
    final repository = _RecordingEpgRepository({
      'live:home': const EpgNowNext(),
      'live:kids': const EpgNowNext(),
    });
    final container = ProviderContainer(
      overrides: [epgRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    Future<EpgNowNextSnapshot> load({
      required String profileId,
      required String sourceId,
      required String entryId,
    }) => container.read(
      epgNowNextProvider(
        EpgNowNextRequest(
          profileId: profileId,
          sourceId: sourceId,
          entries: [
            _entry(
              id: entryId,
              sourceId: sourceId,
              kind: MediaKind.live,
              epgChannelId: 'guide.$entryId',
            ),
          ],
          atUtc: instant,
        ),
      ).future,
    );

    final home = await load(
      profileId: 'profile-home',
      sourceId: 'source-home',
      entryId: 'live:home',
    );
    final kids = await load(
      profileId: 'profile-kids',
      sourceId: 'source-kids',
      entryId: 'live:kids',
    );

    expect(home.profileId, 'profile-home');
    expect(home.sourceId, 'source-home');
    expect(kids.profileId, 'profile-kids');
    expect(kids.sourceId, 'source-kids');
    expect(repository.lookups, [
      ('live:home', instant),
      ('live:kids', instant),
    ]);
  });
}

final class _RecordingEpgRepository implements EpgRepository {
  _RecordingEpgRepository(this._responses);

  final Map<String, EpgNowNext> _responses;
  final List<(String, DateTime)> lookups = [];

  @override
  Future<EpgNowNext> nowNextForChannel(
    String appChannelId,
    DateTime atUtc,
  ) async {
    lookups.add((appChannelId, atUtc));
    return _responses[appChannelId] ?? const EpgNowNext();
  }

  @override
  Future<int> pruneEpgBefore(DateTime cutoffUtc) => throw UnimplementedError();

  @override
  Future<void> replaceEpg({
    required String epgSourceId,
    required Iterable<EpgChannel> channels,
    required Iterable<EpgProgramme> programmes,
    required Iterable<EpgChannelLink> links,
  }) => throw UnimplementedError();

  @override
  Future<List<EpgProgramme>> searchProgrammes({
    required String query,
    required DateTime fromUtc,
    required DateTime toUtc,
    int limit = 50,
  }) => throw UnimplementedError();
}

PersistedMediaEntry _entry({
  required String id,
  required String sourceId,
  required MediaKind kind,
  String? epgChannelId,
}) => PersistedMediaEntry(
  id: id,
  playlistId: sourceId,
  sourceReference: 'fixture-secret-reference',
  originalName: 'Fixture',
  displayName: 'Fixture',
  groupName: 'Fixture',
  kind: kind,
  epgChannelId: epgChannelId,
);
