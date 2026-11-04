import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'qr_pairing_web.dart';

http.Client createProviderHttpClient() {
  final relay = resolveWebPairingRelay(
    const String.fromEnvironment('TVIUM_PAIRING_RELAY'),
  );
  return WebProviderRelayClient(relay);
}

final class WebProviderRelayClient extends http.BaseClient {
  WebProviderRelayClient(this.relay, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final Uri? relay;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') throw const ProviderRelayException();
    final endpoint = relay;
    if (endpoint == null) throw const ProviderRelayException();
    try {
      final session = await _client
          .post(endpoint.resolve('/v1/pairing'))
          .timeout(const Duration(seconds: 10));
      if (session.statusCode != 201) throw const ProviderRelayException();
      final data = jsonDecode(session.body) as Map<String, dynamic>;
      final proxyRequest =
          http.Request('POST', endpoint.resolve('/v1/playlist-fetch'))
            ..headers['Content-Type'] = 'application/json'
            ..headers['Authorization'] =
                'Bearer ${data['id']}.${data['viewerToken']}'
            ..body = jsonEncode({'url': request.url.toString()});
      return await _client
          .send(proxyRequest)
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      rethrow;
    } on ProviderRelayException {
      rethrow;
    } on Object {
      throw const ProviderRelayException();
    }
  }

  @override
  void close() {
    if (_ownsClient) _client.close();
  }
}

final class ProviderRelayException implements Exception {
  const ProviderRelayException();

  @override
  String toString() => 'Web provider relay unavailable';
}
