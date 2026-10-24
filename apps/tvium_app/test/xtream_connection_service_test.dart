import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/features/sources/source_identity_service.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';
import 'package:tvium_app/features/xtream/xtream_connection_service.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
  test(
    'stores credentials only after authentication and catalog load',
    () async {
      final backend = _MemorySecureKeyValueStore();
      final client = MockClient((request) async {
        final action = request.url.queryParameters['action'];
        if (action == null) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'user_info': <String, Object?>{
                'auth': 1,
                'status': 'Active',
                'is_trial': '0',
              },
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      });
      final service = DefaultXtreamConnectionService(
        httpClient: client,
        secretStore: SecureXtreamProfileStore(backend),
        random: Random(1),
      );

      final preview = await service.previewCatalog(_input);
      expect(preview.liveStreams, isEmpty);
      expect(backend.values, isEmpty);

      final result = await service.addPlaylist(_input);

      expect(result.catalog.liveStreams, isEmpty);
      expect(backend.values, hasLength(1));
      expect(backend.values.keys.single, startsWith('tvium.xtream.profile.'));
      expect(service.toString(), isNot(contains('fixture-user')));

      final streamUri = await service.resolveStreamUri(
        result.profileId,
        const XtreamMediaItem(
          id: '42',
          name: 'Fixture channel',
          categoryId: null,
          kind: MediaKind.live,
          imageUri: null,
          containerExtension: null,
          epgChannelId: null,
        ),
      );
      expect(
        streamUri,
        Uri.parse(
          'https://provider.example.test/live/fixture-user/'
          'fixture-password/42.ts',
        ),
      );
    },
  );

  test('does not store credentials when authentication fails', () async {
    final backend = _MemorySecureKeyValueStore();
    final service = DefaultXtreamConnectionService(
      httpClient: MockClient((_) async => http.Response('', 403)),
      secretStore: SecureXtreamProfileStore(backend),
      random: Random(1),
    );

    await expectLater(
      service.addPlaylist(_input),
      throwsA(
        isA<XtreamException>().having(
          (error) => error.failure,
          'failure',
          XtreamFailure.incorrectCredentials,
        ),
      ),
    );
    expect(backend.values, isEmpty);
  });

  test(
    'projects the Xtream EPG channel identifier without stream URLs',
    () async {
      final backend = _MemorySecureKeyValueStore();
      final repository = InMemoryProfileSourceRepository();
      final home = await repository.ensureDefaultProfile();
      final service = DefaultXtreamConnectionService(
        httpClient: MockClient((request) async {
          final action = request.url.queryParameters['action'];
          if (action == null) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'user_info': <String, Object?>{'auth': 1, 'status': 'Active'},
              }),
              200,
            );
          }
          if (action == 'get_live_streams') {
            return http.Response(
              jsonEncode(<Object?>[
                <String, Object?>{
                  'stream_id': '42',
                  'name': 'Fixture News',
                  'epg_channel_id': 'fixture.news.test',
                },
              ]),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
        secretStore: SecureXtreamProfileStore(backend),
        repositoryLoader: () async => repository,
        identityService: SourceIdentityService(backend),
        random: Random(1),
      );

      await service.addPlaylist(_input);

      final source = (await repository.sourcesForProfile(home.id)).single;
      final entry = (await repository.entriesForPlaylist(source.id)).single;
      expect(entry.epgChannelId, 'fixture.news.test');
      expect(entry.sourceReference, isNot(contains('provider.example.test')));
    },
  );

  test('links to the profile active when registration commits', () async {
    final repository = InMemoryProfileSourceRepository();
    final home = await repository.ensureDefaultProfile();
    final kids = await repository.createProfile('Kids');
    final backend = _MemorySecureKeyValueStore();
    var switched = false;
    final service = DefaultXtreamConnectionService(
      httpClient: MockClient((request) async {
        final action = request.url.queryParameters['action'];
        if (action == null) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'user_info': <String, Object?>{'auth': 1, 'status': 'Active'},
            }),
            200,
          );
        }
        if (!switched) {
          switched = true;
          await repository.setActiveProfile(kids.id);
        }
        return http.Response('[]', 200);
      }),
      secretStore: SecureXtreamProfileStore(backend),
      repositoryLoader: () async => repository,
      identityService: SourceIdentityService(backend),
      random: Random(1),
    );

    await service.addPlaylist(_input);

    expect(await repository.sourcesForProfile(home.id), isEmpty);
    expect(await repository.sourcesForProfile(kids.id), hasLength(1));
  });

  test(
    'refreshes an existing source and reports a safe catalog diff',
    () async {
      final repository = InMemoryProfileSourceRepository();
      final profile = await repository.ensureDefaultProfile();
      final backend = _MemorySecureKeyValueStore();
      final secureStore = SecureXtreamProfileStore(backend);
      const source = IptvSource(
        id: 'fixture-reference',
        displayName: 'Fixture',
        identityDigest: 'digest.test',
        secretReference: 'fixture-reference',
      );
      await repository.registerSource(source, profile.id, const [
        PersistedMediaEntry(
          id: 'live:42',
          playlistId: 'fixture-reference',
          sourceReference: 'fixture-reference',
          originalName: 'Old News',
          displayName: 'Old News',
          groupName: null,
          kind: MediaKind.live,
          externalId: '42',
        ),
      ]);
      await secureStore.write(
        'fixture-reference',
        XtreamConnectionSecret(
          serverUri: _input.serverUri,
          credentials: _input.credentials,
        ),
      );
      final service = DefaultXtreamConnectionService(
        httpClient: MockClient((request) async {
          final action = request.url.queryParameters['action'];
          if (action == null) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'user_info': <String, Object?>{'auth': 1, 'status': 'Active'},
              }),
              200,
            );
          }
          if (action == 'get_live_streams') {
            return http.Response(
              jsonEncode(<Object?>[
                <String, Object?>{'stream_id': '42', 'name': 'New News'},
                <String, Object?>{'stream_id': '43', 'name': 'Extra News'},
              ]),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
        secretStore: secureStore,
        repositoryLoader: () async => repository,
      );

      final result = await service.refreshSource('fixture-reference');

      expect(result.addedCount, 1);
      expect(result.changedCount, 1);
      expect(result.removedCount, 0);
      expect(await repository.entriesForPlaylist(source.id), hasLength(2));
      expect(result.toString(), isNot(contains('provider.example.test')));
    },
  );

  test('loads and resolves Xtream series episodes on demand', () async {
    final backend = _MemorySecureKeyValueStore();
    final secureStore = SecureXtreamProfileStore(backend);
    await secureStore.write(
      'fixture-reference',
      XtreamConnectionSecret(
        serverUri: _input.serverUri,
        credentials: _input.credentials,
      ),
    );
    final service = DefaultXtreamConnectionService(
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['action'], 'get_series_info');
        expect(request.url.queryParameters['series_id'], '7');
        return http.Response(
          jsonEncode(<String, Object?>{
            'info': <String, Object?>{'name': 'Fixture show'},
            'episodes': <String, Object?>{
              '1': <Object?>[
                <String, Object?>{
                  'id': '71',
                  'episode_num': 1,
                  'season': 1,
                  'title': 'Pilot',
                  'container_extension': 'mkv',
                },
              ],
            },
          }),
          200,
        );
      }),
      secretStore: secureStore,
    );

    final details = await service.loadSeriesDetails('fixture-reference', '7');
    final episode = details.seasons.single.episodes.single;

    expect(episode.title, 'Pilot');
    expect(
      await service.resolveEpisodeStreamUri('fixture-reference', episode),
      Uri.parse(
        'https://provider.example.test/series/fixture-user/'
        'fixture-password/71.mkv',
      ),
    );
  });
}

final _input = XtreamConnectionInput(
  profileName: 'Fixture',
  serverUri: Uri.parse('https://provider.example.test'),
  credentials: const XtreamCredentials(
    username: 'fixture-user',
    password: 'fixture-password',
  ),
);

final class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
