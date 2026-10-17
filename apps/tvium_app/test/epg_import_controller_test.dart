import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/epg/epg_import_controller.dart';
import 'package:tvium_app/features/epg/epg_source.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_epg/tvium_epg.dart';

void main() {
  group('EpgImportController', () {
    test(
      'atomically replaces a parsed guide with matched live channels',
      () async {
        final epgRepository = _RecordingEpgRepository();
        final libraryRepository = _LibraryRepository([
          const PersistedMediaEntry(
            id: 'channel-news',
            playlistId: 'source.test',
            sourceReference: 'secret-reference',
            originalName: 'News HD',
            displayName: 'News HD',
            groupName: 'News',
            kind: MediaKind.live,
            epgChannelId: 'news.test',
          ),
          const PersistedMediaEntry(
            id: 'channel-sport',
            playlistId: 'source.test',
            sourceReference: 'secret-reference',
            originalName: 'Sport +',
            displayName: 'Sport +',
            groupName: 'Sport',
            kind: MediaKind.live,
          ),
          const PersistedMediaEntry(
            id: 'movie-one',
            playlistId: 'source.test',
            sourceReference: 'secret-reference',
            originalName: 'Movie One',
            displayName: 'Movie One',
            groupName: 'Movies',
            kind: MediaKind.movie,
          ),
        ]);
        final controller = EpgImportController(
          epgRepository: epgRepository,
          libraryRepository: libraryRepository,
        );

        await controller.importSource(
          EpgBytesSource(
            sourceId: 'guide.test',
            bytes: utf8.encode(_validXmltv),
          ),
        );

        expect(controller.state.phase, EpgImportPhase.ready);
        expect(controller.state.channelCount, 2);
        expect(controller.state.programmeCount, 2);
        expect(controller.state.matchedChannelCount, 2);
        expect(epgRepository.replacements, hasLength(1));
        final replacement = epgRepository.replacements.single;
        expect(replacement.epgSourceId, 'guide.test');
        expect(
          replacement.links
              .map((link) => '${link.appChannelId}:${link.xmltvChannelId}')
              .toSet(),
          {'channel-news:news.test', 'channel-sport:sport.test'},
        );
        expect(
          replacement.links.map((link) => link.appChannelId),
          isNot(contains('movie-one')),
        );
      },
    );

    test('leaves ambiguous live channels unmatched', () async {
      final epgRepository = _RecordingEpgRepository();
      final controller = EpgImportController(
        epgRepository: epgRepository,
        libraryRepository: _LibraryRepository([
          const PersistedMediaEntry(
            id: 'channel-ambiguous',
            playlistId: 'source.test',
            sourceReference: 'secret-reference',
            originalName: 'News HD',
            displayName: 'News HD',
            groupName: 'News',
            kind: MediaKind.live,
          ),
        ]),
      );

      await controller.importSource(
        EpgBytesSource(
          sourceId: 'guide.test',
          bytes: utf8.encode('''
<tv>
  <channel id="one.test"><display-name>News HD</display-name></channel>
  <channel id="two.test"><display-name>News HD</display-name></channel>
</tv>
'''),
        ),
      );

      expect(controller.state.phase, EpgImportPhase.ready);
      expect(controller.state.matchedChannelCount, 0);
      expect(epgRepository.replacements.single.links, isEmpty);
    });

    test(
      'matches session-only M3U candidates without persisting stream data',
      () async {
        final epgRepository = _RecordingEpgRepository();
        final controller = EpgImportController(
          epgRepository: epgRepository,
          libraryRepository: _LibraryRepository(const []),
        );

        await controller.importSource(
          EpgBytesSource(
            sourceId: 'guide.test',
            bytes: utf8.encode(_validXmltv),
          ),
          additionalEntries: const [
            PersistedMediaEntry(
              id: 'session-news',
              playlistId: 'session.m3u',
              sourceReference: 'session-only',
              originalName: 'News HD',
              displayName: 'News HD',
              groupName: 'News',
              kind: MediaKind.live,
              epgChannelId: 'news.test',
            ),
          ],
        );

        expect(
          epgRepository.replacements.single.links.single.appChannelId,
          'session-news',
        );
      },
    );

    test('does not replace cached data when parsing fails', () async {
      final epgRepository = _RecordingEpgRepository();
      final controller = EpgImportController(
        epgRepository: epgRepository,
        libraryRepository: _LibraryRepository(const []),
      );

      await controller.importSource(
        EpgBytesSource(
          sourceId: 'guide.test',
          bytes: utf8.encode('<tv><broken>'),
        ),
      );

      expect(controller.state.phase, EpgImportPhase.failed);
      expect(
        controller.state.message,
        'The programme guide could not be imported.',
      );
      expect(epgRepository.replacements, isEmpty);
    });

    test('never exposes provider details from persistence failures', () async {
      const secret = 'password=private-value';
      const endpoint = 'https://provider.example.test/guide.xml?token=private';
      final controller = EpgImportController(
        epgRepository: _RecordingEpgRepository(
          failure: Exception('$secret $endpoint'),
        ),
        libraryRepository: _LibraryRepository(const []),
      );

      await controller.importSource(
        EpgBytesSource(sourceId: 'guide.test', bytes: utf8.encode('<tv></tv>')),
      );

      expect(controller.state.phase, EpgImportPhase.failed);
      expect(controller.state.toString(), isNot(contains(secret)));
      expect(controller.state.toString(), isNot(contains(endpoint)));
      expect(
        controller.state.message,
        isNot(contains('provider.example.test')),
      );
      expect(controller.state.message, isNot(contains('private')));
    });
  });

  group('EPG sources', () {
    test(
      'reads local bytes without revealing their source identifier',
      () async {
        final source = EpgBytesSource(
          sourceId: 'local-guide.test',
          bytes: utf8.encode('<tv></tv>'),
        );

        expect(
          await source.readBytes().expand((chunk) => chunk).toList(),
          utf8.encode('<tv></tv>'),
        );
        expect(source.toString(), isNot(contains('local-guide.test')));
      },
    );

    test('uses an injected HTTPS reader and keeps the URL out of diagnostics', () async {
      const endpoint =
          'https://provider.example.test/guide.xml?username=user&password=secret';
      Uri? requestedUri;
      final source = EpgHttpsSource(
        Uri.parse(endpoint),
        opener: (uri) {
          requestedUri = uri;
          return Stream.value(utf8.encode('<tv></tv>'));
        },
      );

      expect(
        await source.readBytes().expand((chunk) => chunk).toList(),
        utf8.encode('<tv></tv>'),
      );
      expect(requestedUri, Uri.parse(endpoint));
      expect(source.sourceId, startsWith('https-'));
      expect(source.sourceId, isNot(contains('provider')));
      expect(source.toString(), isNot(contains('provider.example.test')));
      expect(source.toString(), isNot(contains('secret')));
    });

    test('rejects non-HTTPS remote programme guides', () {
      expect(
        () => EpgHttpsSource(Uri.parse('http://provider.example.test/guide')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

const _validXmltv = '''
<tv>
  <channel id="news.test"><display-name>News HD</display-name></channel>
  <channel id="sport.test"><display-name>Sport +</display-name></channel>
  <programme channel="news.test" start="20261016100000 +0000" stop="20261016110000 +0000">
    <title>Morning News</title>
  </programme>
  <programme channel="sport.test" start="20261016100000 +0000" stop="20261016110000 +0000">
    <title>Live Sport</title>
  </programme>
</tv>
''';

final class _EpgReplacement {
  const _EpgReplacement({
    required this.epgSourceId,
    required this.channels,
    required this.programmes,
    required this.links,
  });

  final String epgSourceId;
  final List<EpgChannel> channels;
  final List<EpgProgramme> programmes;
  final List<EpgChannelLink> links;
}

final class _RecordingEpgRepository implements EpgRepository {
  _RecordingEpgRepository({this.failure});

  final Object? failure;
  final replacements = <_EpgReplacement>[];

  @override
  Future<void> replaceEpg({
    required String epgSourceId,
    required Iterable<EpgChannel> channels,
    required Iterable<EpgProgramme> programmes,
    required Iterable<EpgChannelLink> links,
  }) async {
    if (failure case final error?) throw error;
    replacements.add(
      _EpgReplacement(
        epgSourceId: epgSourceId,
        channels: channels.toList(),
        programmes: programmes.toList(),
        links: links.toList(),
      ),
    );
  }

  @override
  Future<EpgNowNext> nowNextForChannel(String appChannelId, DateTime atUtc) =>
      throw UnimplementedError();

  @override
  Future<int> pruneEpgBefore(DateTime cutoffUtc) => throw UnimplementedError();

  @override
  Future<List<EpgProgramme>> searchProgrammes({
    required String query,
    required DateTime fromUtc,
    required DateTime toUtc,
    int limit = 50,
  }) => throw UnimplementedError();
}

final class _LibraryRepository implements ProfileSourceRepository {
  _LibraryRepository(this.entries);

  final List<PersistedMediaEntry> entries;
  static const _profile = UserProfile('profile.test', 'Test');
  static const _source = IptvSource(
    id: 'source.test',
    displayName: 'Test source',
    identityDigest: 'digest.test',
    secretReference: 'secret-reference',
  );

  @override
  Future<UserProfile> activeProfile() async => _profile;

  @override
  Future<List<PersistedMediaEntry>> entriesForPlaylist(String sourceId) async =>
      sourceId == _source.id ? entries : const [];

  @override
  Future<List<IptvSource>> sourcesForProfile(String profileId) async =>
      profileId == _profile.id ? const [_source] : const [];

  @override
  Future<void> close() async {}

  @override
  Future<UserProfile> createProfile(String name) => throw UnimplementedError();

  @override
  Future<UserProfile> ensureDefaultProfile() async => _profile;

  @override
  Future<void> linkSource(String profileId, String sourceId) =>
      throw UnimplementedError();

  @override
  Future<List<UserProfile>> profiles() async => const [_profile];

  @override
  Future<void> registerSource(
    IptvSource source,
    String profileId,
    List<PersistedMediaEntry> entries,
  ) => throw UnimplementedError();

  @override
  Future<void> setActiveProfile(String id) => throw UnimplementedError();

  @override
  Future<IptvSource?> sourceByIdentity(String digest) async => null;
}
