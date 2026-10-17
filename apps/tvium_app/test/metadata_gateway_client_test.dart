import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/features/metadata/metadata_gateway_client.dart';
import 'package:tvium_core/tvium_core.dart';

void main() {
  test(
    'sends only cleaned identity fields and caches successful results',
    () async {
      var requests = 0;
      final client = MetadataGatewayClient(
        endpoint: Uri.parse('https://metadata.example.test'),
        client: MockClient((request) async {
          requests++;
          expect(jsonDecode(request.body), {
            'title': 'Arrival',
            'kind': 'movie',
            'year': 2016,
            'language': 'en',
          });
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'id': '1',
                  'provider': 'tmdb',
                  'title': 'Arrival',
                  'kind': 'movie',
                  'year': 2016,
                  'overview': 'A visitor arrives.',
                  'sourceUrl': 'https://www.themoviedb.org/movie/1',
                  'license': 'TMDB terms',
                },
              ],
            }),
            200,
          );
        }),
      );
      final title = const PlaylistTitleNormalizer().normalize(
        '[EN] Arrival (2016) [4K]',
        kind: MediaKind.movie,
      );
      final first = await client.search(title);
      final second = await client.search(title);
      expect(first.single.candidate.title, 'Arrival');
      expect(second.single.overview, 'A visitor arrives.');
      expect(requests, 1);
    },
  );

  test('blocks source URLs before any network request', () async {
    var requests = 0;
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient((_) async {
        requests++;
        return http.Response(jsonEncode({'candidates': <Object>[]}), 200);
      }),
    );
    for (final title in [
      'https://provider.example.test/u/p',
      'rtsp://provider.example.test/live/stream',
      'provider.example.test/live/stream',
    ]) {
      await expectLater(
        client.search(
          NormalizedPlaylistTitle(
            originalTitle: 'private',
            title: title,
            kind: MediaKind.movie,
          ),
        ),
        throwsA(isA<MetadataLookupException>()),
      );
    }
    expect(requests, 0);
  });

  test(
    'allows ordinary title punctuation without exposing source data',
    () async {
      final client = MetadataGatewayClient(
        endpoint: Uri.parse('https://metadata.example.test'),
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'title': 'Mission: Impossible?',
            'kind': 'movie',
            'year': 1996,
            'language': 'en',
          });
          expect(request.body, isNot(contains('playlist.example.test')));
          return http.Response(jsonEncode({'candidates': <Object>[]}), 200);
        }),
      );
      await client.search(
        const NormalizedPlaylistTitle(
          originalTitle: 'https://playlist.example.test/private-source',
          title: 'Mission: Impossible?',
          kind: MediaKind.movie,
          year: 1996,
        ),
      );
    },
  );

  test('blocks credential-shaped titles before any network request', () async {
    var requests = 0;
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient((_) async {
        requests++;
        return http.Response(jsonEncode({'candidates': <Object>[]}), 200);
      }),
    );
    for (final title in [
      'username=user&password=secret',
      'user@example.test',
      'Bearer abc.def.ghi',
    ]) {
      await expectLater(
        client.search(
          NormalizedPlaylistTitle(
            originalTitle: title,
            title: title,
            kind: MediaKind.movie,
          ),
        ),
        throwsA(isA<MetadataLookupException>()),
      );
    }
    expect(requests, 0);
  });

  test('provider errors never surface raw response bodies', () async {
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient(
        (_) async => http.Response('private-provider-detail', 502),
      ),
    );
    await expectLater(
      client.search(
        const NormalizedPlaylistTitle(
          originalTitle: 'Arrival',
          title: 'Arrival',
          kind: MediaKind.movie,
        ),
      ),
      throwsA(
        isA<MetadataLookupException>().having(
          (error) => error.toString(),
          'safe error',
          isNot(contains('private-provider')),
        ),
      ),
    );
  });
}
