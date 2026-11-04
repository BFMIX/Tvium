import 'dart:convert';

import 'package:http/http.dart' as http;

import '../import/qr_pairing_web.dart';

Future<Uri> prepareMediaUri(
  Uri source, {
  http.Client? client,
  Uri? relay,
  bool xtreamLive = false,
}) async {
  if (xtreamLive && source.path.toLowerCase().endsWith('.ts')) {
    final segments = source.pathSegments.toList();
    final last = segments.removeLast();
    source = source.replace(
      pathSegments: <String>[
        ...segments,
        '${last.substring(0, last.length - 3)}.m3u8',
      ],
    );
  }
  final endpoint =
      relay ??
      resolveWebPairingRelay(
        const String.fromEnvironment('TVIUM_PAIRING_RELAY'),
      );
  if (endpoint == null) throw const MediaRelayException();
  final httpClient = client ?? http.Client();
  try {
    final session = await httpClient
        .post(endpoint.resolve('/v1/pairing'))
        .timeout(const Duration(seconds: 10));
    if (session.statusCode != 201) throw const MediaRelayException();
    final data = jsonDecode(session.body) as Map<String, dynamic>;
    final response = await httpClient
        .post(
          endpoint.resolve('/v1/media-session'),
          headers: {
            'Authorization': 'Bearer ${data['id']}.${data['viewerToken']}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'url': source.toString()}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 201) throw const MediaRelayException();
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final url = Uri.tryParse(result['url'] as String? ?? '');
    if (url == null || url.scheme != 'https' || url.origin != endpoint.origin) {
      throw const MediaRelayException();
    }
    return url;
  } on MediaRelayException {
    rethrow;
  } on Object {
    throw const MediaRelayException();
  } finally {
    if (client == null) httpClient.close();
  }
}

final class MediaRelayException implements Exception {
  const MediaRelayException();

  @override
  String toString() => 'Media relay unavailable';
}
