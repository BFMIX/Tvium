import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/features/home/web_media_relay.dart';
import 'package:tvium_app/features/import/web_provider_relay_client.dart';

void main() {
  final relay = Uri.parse('https://relay.example.test');

  test(
    'provider client sends the source in a POST body, never in the relay URL',
    () async {
      final requests = <http.Request>[];
      final client = WebProviderRelayClient(
        relay,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/v1/pairing') {
            return http.Response(
              jsonEncode({'id': 'session', 'viewerToken': 'token'}),
              201,
            );
          }
          return http.Response('#EXTM3U\n', 200);
        }),
      );
      final source = Uri.parse(
        'http://provider.example.test/get.php?password=secret',
      );
      final response = await client.get(source);
      expect(response.body, '#EXTM3U\n');
      expect(requests.map((request) => request.url.path), [
        '/v1/pairing',
        '/v1/playlist-fetch',
      ]);
      expect(requests.last.url.toString(), isNot(contains('secret')));
      expect(
        (jsonDecode(requests.last.body) as Map<String, dynamic>)['url'],
        source.toString(),
      );
      expect(requests.last.headers['Authorization'], 'Bearer session.token');
      client.close();
    },
  );

  test(
    'media session returns an opaque HTTPS URL from the configured relay',
    () async {
      final source = Uri.parse('http://provider.example.test/live/u/p/1.m3u8');
      final client = MockClient((request) async {
        if (request.url.path == '/v1/pairing') {
          return http.Response(
            jsonEncode({'id': 'session', 'viewerToken': 'token'}),
            201,
          );
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/media-session');
        expect(
          (jsonDecode(request.body) as Map<String, dynamic>)['url'],
          source.toString(),
        );
        return http.Response(
          jsonEncode({
            'url': 'https://relay.example.test/v1/media/opaque/stream.m3u8',
          }),
          201,
        );
      });
      final playable = await prepareMediaUri(
        source,
        client: client,
        relay: relay,
      );
      expect(playable.scheme, 'https');
      expect(playable.toString(), isNot(contains('provider.example.test')));
    },
  );

  test(
    'Xtream live transport requests HLS instead of MPEG-TS on Web',
    () async {
      final source = Uri.parse('http://provider.example.test/live/u/p/1.ts');
      final client = MockClient((request) async {
        if (request.url.path == '/v1/pairing') {
          return http.Response(
            jsonEncode({'id': 'session', 'viewerToken': 'token'}),
            201,
          );
        }
        expect(
          (jsonDecode(request.body) as Map<String, dynamic>)['url'],
          'http://provider.example.test/live/u/p/1.m3u8',
        );
        return http.Response(
          jsonEncode({
            'url': 'https://relay.example.test/v1/media/opaque/stream.m3u8',
          }),
          201,
        );
      });
      await prepareMediaUri(
        source,
        client: client,
        relay: relay,
        xtreamLive: true,
      );
    },
  );
}
