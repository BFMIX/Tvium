import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tvium_m3u/tvium_m3u.dart';

import 'qr_pairing_web.dart';

M3uSource createPlaylistUrlSource(Uri uri) => _WebPlaylistUrlSource(uri);

final class _WebPlaylistUrlSource implements M3uSource {
  _WebPlaylistUrlSource(this.uri);

  final Uri uri;

  @override
  Stream<String> readLines() async* {
    final relay = resolveWebPairingRelay(
      const String.fromEnvironment('TVIUM_PAIRING_RELAY'),
    );
    if (relay == null) {
      throw const M3uSourceException('Web playlist relay is unavailable.');
    }
    final client = _PlaylistRelayClient(relay);
    try {
      yield* M3uUrlSource(
        uri,
        client: client,
        timeout: const Duration(seconds: 45),
      ).readLines();
    } finally {
      client.close();
    }
  }
}

final class _PlaylistRelayClient extends http.BaseClient {
  _PlaylistRelayClient(this.relay);

  final Uri relay;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final session = await _client
        .post(relay.resolve('/v1/pairing'))
        .timeout(const Duration(seconds: 10));
    if (session.statusCode != 201) {
      throw const M3uSourceException('Web playlist relay is unavailable.');
    }
    final data = jsonDecode(session.body) as Map<String, dynamic>;
    final id = data['id'] as String;
    final viewerToken = data['viewerToken'] as String;
    final proxyRequest =
        http.Request('POST', relay.resolve('/v1/playlist-fetch'))
          ..headers['Content-Type'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $id.$viewerToken'
          ..body = jsonEncode({'url': request.url.toString()});
    return _client.send(proxyRequest).timeout(const Duration(seconds: 45));
  }

  @override
  void close() => _client.close();
}
