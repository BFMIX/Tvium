import 'dart:async';
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
    serverUri: Uri.parse('https://provider.example.test:8443'),
    credentialReference: 'secret-home',
  );

  test(
    'authenticates and tolerates numeric values encoded as strings',
    () async {
      late Uri requestedUri;
      final client = XtreamClient(
        MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode(<String, Object>{
              'user_info': <String, Object>{
                'auth': 1,
                'status': 'Active',
                'exp_date': '1893456000',
                'is_trial': '0',
                'active_cons': '1',
                'max_connections': '2',
              },
              'server_info': <String, Object>{'timezone': 'Europe/Paris'},
            }),
            200,
          );
        }),
      );

      final account = await client.authenticate(profile, credentials);

      expect(requestedUri.path, '/player_api.php');
      expect(requestedUri.queryParameters['username'], 'fixture-user');
      expect(requestedUri.queryParameters['password'], 'fixture-password');
      expect(account.status, XtreamAccountStatus.active);
      expect(account.isTrial, isFalse);
      expect(account.activeConnections, 1);
      expect(account.maximumConnections, 2);
      expect(account.expiresAt, DateTime.utc(2030));
      expect(account.timezone, 'Europe/Paris');
    },
  );

  test('rejects an inactive login with a credential-free failure', () async {
    final client = XtreamClient(
      MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object>{
            'user_info': <String, Object>{'auth': 0, 'status': 'Disabled'},
          }),
          200,
        ),
      ),
    );

    await expectLater(
      client.authenticate(profile, credentials),
      throwsA(
        isA<XtreamException>()
            .having(
              (error) => error.failure,
              'failure',
              XtreamFailure.incorrectCredentials,
            )
            .having(
              (error) => error.toString(),
              'safe message',
              allOf(
                isNot(contains('fixture-user')),
                isNot(contains('fixture-password')),
                isNot(contains('provider.example.test')),
              ),
            ),
      ),
    );
  });

  test(
    'profile and credentials never reveal connection values in debug text',
    () {
      expect(profile.toString(), isNot(contains('provider.example.test')));
      expect(profile.toString(), isNot(contains('secret-home')));
      expect(credentials.toString(), isNot(contains('fixture-user')));
      expect(credentials.toString(), isNot(contains('fixture-password')));
    },
  );

  test('loads a mixed catalog and skips one malformed record', () async {
    final client = XtreamClient(
      MockClient((request) async {
        expect(request.url.queryParameters['username'], 'fixture-user');
        expect(request.url.queryParameters['password'], 'fixture-password');
        final body = switch (request.url.queryParameters['action']) {
          'get_live_categories' => <Object>[
            <String, Object>{'category_id': '10', 'category_name': 'News'},
          ],
          'get_live_streams' => <Object>[
            <String, Object>{
              'stream_id': 100,
              'name': 'Demo News',
              'category_id': '10',
              'stream_icon': 'https://images.example.test/news.png',
              'epg_channel_id': 'demo.news',
            },
            <String, Object>{'name': 'Missing stream identifier'},
          ],
          'get_vod_categories' => <Object>[
            <String, Object>{'category_id': 20, 'category_name': 'Movies'},
          ],
          'get_vod_streams' => <Object>[
            <String, Object>{
              'stream_id': '200',
              'name': 'Demo Movie',
              'category_id': 20,
              'container_extension': 'mp4',
            },
          ],
          'get_series_categories' => <Object>[
            <String, Object>{'category_id': '30', 'category_name': 'Series'},
          ],
          'get_series' => <Object>[
            <String, Object>{
              'series_id': 300,
              'name': 'Demo Series',
              'category_id': '30',
              'cover': 'https://images.example.test/series.jpg',
            },
          ],
          _ => fail('Unexpected Xtream action'),
        };
        return http.Response(jsonEncode(body), 200);
      }),
    );

    final catalog = await client.loadCatalog(profile, credentials);

    expect(catalog.liveCategories.single.id, '10');
    expect(catalog.liveStreams.single.id, '100');
    expect(catalog.liveStreams.single.epgChannelId, 'demo.news');
    expect(catalog.movieCategories.single.id, '20');
    expect(catalog.movies.single.containerExtension, 'mp4');
    expect(catalog.seriesCategories.single.id, '30');
    expect(catalog.series.single.id, '300');
    expect(catalog.warnings, hasLength(1));
    expect(catalog.warnings.single, isNot(contains('fixture-user')));
    expect(catalog.warnings.single, isNot(contains('fixture-password')));
  });

  test('catalog uses its own timeout and reports each safe step', () async {
    final steps = <XtreamCatalogStep>[];
    final client = XtreamClient(
      MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        return http.Response('[]', 200);
      }),
      timeout: const Duration(milliseconds: 5),
      catalogTimeout: const Duration(milliseconds: 100),
    );
    await client.loadCatalog(
      profile,
      credentials,
      onProgress: (step, current, total) {
        expect(current, steps.length + 1);
        expect(total, 6);
        steps.add(step);
      },
    );
    expect(steps, XtreamCatalogStep.values);
  });

  test('reports the timed-out catalog step without request details', () async {
    final client = XtreamClient(
      MockClient((request) async {
        if (request.url.queryParameters['action'] == 'get_vod_streams') {
          await Completer<void>().future;
        }
        return http.Response('[]', 200);
      }),
      catalogTimeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      client.loadCatalog(profile, credentials),
      throwsA(
        isA<XtreamException>()
            .having(
              (error) => error.failure,
              'failure',
              XtreamFailure.networkTimeout,
            )
            .having(
              (error) => error.catalogStep,
              'step',
              XtreamCatalogStep.vodStreams,
            )
            .having(
              (error) => error.toString(),
              'safe text',
              isNot(contains('provider.example.test')),
            ),
      ),
    );
  });

  test('optional partial import retains Live when VOD times out', () async {
    final client = XtreamClient(
      MockClient((request) async {
        final action = request.url.queryParameters['action'];
        if (action == 'get_vod_streams') await Completer<void>().future;
        return http.Response(
          action == 'get_live_streams'
              ? '[{"stream_id":1,"name":"Fixture Live"}]'
              : '[]',
          200,
        );
      }),
      catalogTimeout: const Duration(milliseconds: 5),
    );
    final catalog = await client.loadCatalog(
      profile,
      credentials,
      allowPartialCatalog: true,
    );
    expect(catalog.liveStreams.single.name, 'Fixture Live');
    expect(catalog.movies, isEmpty);
    expect(
      catalog.warnings,
      contains('The vodStreams catalog timed out and was skipped.'),
    );
  });
}
