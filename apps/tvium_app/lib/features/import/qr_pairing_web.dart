import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import 'qr_pairing.dart';

Uri? resolveWebPairingRelay(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.userInfo.isNotEmpty ||
      !uri.hasAuthority ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  if (uri.scheme == 'https') return uri;
  if (uri.scheme == 'http' &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
    return uri;
  }
  return null;
}

Future<QrPairingSession> startQrPairing({
  Uri? relay,
  http.Client? client,
  Duration pollInterval = const Duration(seconds: 2),
}) async {
  final endpoint =
      relay ??
      resolveWebPairingRelay(
        const String.fromEnvironment('TVIUM_PAIRING_RELAY'),
      );
  if (endpoint == null || resolveWebPairingRelay(endpoint.toString()) == null) {
    throw StateError('Web pairing relay is unavailable');
  }
  final ownedClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .post(endpoint.resolve('/v1/pairing'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 201) throw StateError('Pairing is unavailable');
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final id = result['id'] as String;
    final viewerToken = result['viewerToken'] as String;
    final submitToken = result['submitToken'] as String;
    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    final encodedKey = base64UrlEncode(key).replaceAll('=', '');
    final url = endpoint
        .resolve('/pair/')
        .replace(fragment: 'id=$id&submit=$submitToken&key=$encodedKey');
    return _WebQrPairingSession(
      httpClient,
      ownedClient,
      endpoint,
      id,
      viewerToken,
      key,
      url.toString(),
      pollInterval,
    );
  } on Object {
    if (ownedClient) httpClient.close();
    rethrow;
  }
}

final class _WebQrPairingSession implements QrPairingSession {
  _WebQrPairingSession(
    this._client,
    this._ownedClient,
    this._relay,
    this._id,
    this._viewerToken,
    this._key,
    this.pairingUrl,
    this._pollInterval,
  ) {
    unawaited(_poll());
  }

  final http.Client _client;
  final bool _ownedClient;
  final Uri _relay;
  final String _id;
  final String _viewerToken;
  final List<int> _key;
  final Duration _pollInterval;
  final Completer<QrPairingSubmission?> _received = Completer();
  bool _closed = false;

  @override
  final String pairingUrl;

  @override
  Future<QrPairingSubmission?> get submission => _received.future;

  Future<void> _poll() async {
    final expires = DateTime.now().add(const Duration(minutes: 10));
    while (!_closed && DateTime.now().isBefore(expires)) {
      var receivedPayload = false;
      try {
        final response = await _client
            .get(
              _relay.resolve('/v1/pairing/$_id/submission'),
              headers: {'Authorization': 'Bearer $_viewerToken'},
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          receivedPayload = true;
          final payload = jsonDecode(response.body) as Map<String, dynamic>;
          final nonce = base64Url.decode(
            base64Url.normalize(payload['iv'] as String),
          );
          final encrypted = base64Url.decode(
            base64Url.normalize(payload['ciphertext'] as String),
          );
          if (nonce.length != 12 || encrypted.length < 16) break;
          final clear = await AesGcm.with256bits().decrypt(
            SecretBox(
              encrypted.sublist(0, encrypted.length - 16),
              nonce: nonce,
              mac: Mac(encrypted.sublist(encrypted.length - 16)),
            ),
            secretKey: SecretKey(_key),
          );
          final proposal = parseQrPairingSubmission(utf8.decode(clear));
          if (!_received.isCompleted) _received.complete(proposal);
          return;
        }
        if (response.statusCode != 202) break;
      } on Object {
        if (receivedPayload) break;
        // Transient network errors may recover before the session expires.
      }
      await Future<void>.delayed(_pollInterval);
    }
    if (!_received.isCompleted) _received.complete(null);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_received.isCompleted) _received.complete(null);
    try {
      await _client
          .delete(
            _relay.resolve('/v1/pairing/$_id'),
            headers: {'Authorization': 'Bearer $_viewerToken'},
          )
          .timeout(const Duration(seconds: 5));
    } on Object {
      // The relay expires abandoned sessions independently.
    } finally {
      if (_ownedClient) _client.close();
    }
  }
}
