import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
  const credentials = XtreamCredentials(
    username: 'fixture-user',
    password: 'fixture-password',
  );
  final profile = XtreamProfile(
    id: 'home',
    displayName: 'Home',
    serverUri: Uri.parse('https://provider.example.test:8443/base'),
    credentialReference: 'secret-home',
  );

  test('loads series details with ordered seasons and episodes', () async {
    late Uri requestedUri;
    final client = XtreamClient(
      MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode(<String, Object?>{
            'info': <String, Object?>{
              'name': 'Fixture Series',
              'cover': 'https://images.example.test/cover.jpg',
              'backdrop_path': <Object?>[
                'https://images.example.test/backdrop.jpg',
              ],
              'plot': 'A safe synthetic synopsis.',
              'genre': 'Drama',
              'rating': '8.4',
              'releaseDate': '2025-01-02',
            },
            'seasons': <Object?>[
              <String, Object?>{
                'id': 12,
                'season_number': 2,
                'name': 'Season Two',
                'overview': 'Second season.',
                'cover': 'https://images.example.test/season-2.jpg',
              },
              <String, Object?>{
                'id': 11,
                'season_number': 1,
                'name': 'Season One',
              },
            ],
            'episodes': <String, Object?>{
              '2': <Object?>[
                <String, Object?>{
                  'id': 202,
                  'episode_num': 2,
                  'title': 'Second Episode',
                  'container_extension': 'mkv',
                  'season': 2,
                  'info': <String, Object?>{
                    'movie_image': 'https://images.example.test/episode-2.jpg',
                    'plot': 'Episode synopsis.',
                    'rating': '7.5',
                    'releasedate': '2025-02-03',
                    'duration_secs': 2700,
                  },
                },
                <String, Object?>{'title': 'Missing identifier'},
              ],
              '1': <Object?>[
                <String, Object?>{
                  'id': '101',
                  'episode_num': '1',
                  'title': 'First Episode',
                  'container_extension': 'mp4',
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final details = await client.loadSeriesDetails(
      profile,
      credentials,
      seriesId: '300',
    );

    expect(requestedUri.path, '/base/player_api.php');
    expect(requestedUri.queryParameters['action'], 'get_series_info');
    expect(requestedUri.queryParameters['series_id'], '300');
    expect(details.id, '300');
    expect(details.name, 'Fixture Series');
    expect(details.rating, 8.4);
    expect(details.releasedAt, DateTime.utc(2025, 1, 2));
    expect(details.backdropUris.single.host, 'images.example.test');
    expect(details.seasons.map((season) => season.number), <int>[1, 2]);
    expect(details.seasons.first.episodes.single.id, '101');
    final episode = details.seasons.last.episodes.single;
    expect(episode.seasonNumber, 2);
    expect(episode.number, 2);
    expect(episode.duration, const Duration(minutes: 45));
    expect(episode.releasedAt, DateTime.utc(2025, 2, 3));
    expect(details.warnings, <String>['Skipped malformed episode record.']);
  });

  test('keeps an episode-only season when season metadata is absent', () async {
    final client = XtreamClient(
      MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'info': <String, Object?>{'name': 'Fixture Series'},
            'episodes': <String, Object?>{
              '3': <Object?>[
                <String, Object?>{
                  'id': '301',
                  'episode_num': '4',
                  'title': 'Fourth Episode',
                  'container_extension': 'mp4',
                },
              ],
            },
          }),
          200,
        ),
      ),
    );

    final details = await client.loadSeriesDetails(
      profile,
      credentials,
      seriesId: '300',
    );

    expect(details.seasons.single.number, 3);
    expect(details.seasons.single.name, 'Season 3');
    expect(details.seasons.single.episodes.single.number, 4);
  });

  test('rejects a malformed series details response safely', () async {
    final client = XtreamClient(
      MockClient((_) async => http.Response(jsonEncode(<Object?>[]), 200)),
    );

    await expectLater(
      client.loadSeriesDetails(profile, credentials, seriesId: '300'),
      throwsA(
        isA<XtreamException>().having(
          (error) => error.failure,
          'failure',
          XtreamFailure.invalidResponse,
        ),
      ),
    );
  });

  test('builds an encoded series episode stream URI', () {
    final uri = XtreamStreamUriBuilder.buildEpisode(
      profile: profile,
      credentials: credentials,
      episode: const XtreamEpisode(
        id: '202',
        seasonNumber: 2,
        number: 2,
        title: 'Second Episode',
        containerExtension: 'mkv',
        imageUri: null,
        plot: null,
        releasedAt: null,
        rating: null,
        duration: null,
      ),
    );

    expect(
      uri.toString(),
      'https://provider.example.test:8443/base/series/fixture-user/'
      'fixture-password/202.mkv',
    );
  });
}
