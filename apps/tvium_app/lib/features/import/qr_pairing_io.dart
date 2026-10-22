import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'qr_pairing.dart';

Future<QrPairingSession> startQrPairing({
  InternetAddress? bindAddress,
  Duration lifetime = const Duration(minutes: 10),
}) async {
  final address = bindAddress ?? await _privateLanAddress();
  if (address == null) {
    throw const SocketException('No local network available');
  }
  final server = await HttpServer.bind(address, 0);
  final random = Random.secure();
  final token = base64UrlEncode(
    List<int>.generate(32, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
  return _LocalQrPairingSession(server, token, lifetime);
}

Future<InternetAddress?> _privateLanAddress() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      final bytes = address.rawAddress;
      if (bytes[0] == 10 ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168)) {
        return address;
      }
    }
  }
  return null;
}

final class _LocalQrPairingSession implements QrPairingSession {
  _LocalQrPairingSession(this._server, this._token, Duration lifetime) {
    _expiry = Timer(lifetime, () => unawaited(close()));
    _requests = _server.listen((request) => unawaited(_handle(request)));
  }

  final HttpServer _server;
  final String _token;
  final Completer<QrPairingSubmission?> _received = Completer();
  late final Timer _expiry;
  late final StreamSubscription<HttpRequest> _requests;
  bool _closed = false;

  @override
  String get pairingUrl =>
      'http://${_server.address.address}:${_server.port}/pair/$_token';

  @override
  Future<QrPairingSubmission?> get submission => _received.future;

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('Referrer-Policy', 'no-referrer');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set(
      'Content-Security-Policy',
      "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'",
    );
    if (_closed || request.uri.path != '/pair/$_token') {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    if (request.method == 'GET') {
      response.headers.contentType = ContentType.html;
      response.write(_phoneForm);
      await response.close();
      return;
    }
    if (request.method != 'POST' || _received.isCompleted) {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    if (request.headers.contentType?.mimeType !=
        'application/x-www-form-urlencoded') {
      response.statusCode = HttpStatus.unsupportedMediaType;
      await response.close();
      return;
    }
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > 4096) {
        response.statusCode = HttpStatus.requestEntityTooLarge;
        await response.close();
        return;
      }
    }
    QrPairingSubmission? proposal;
    try {
      proposal = parseQrPairingSubmission(utf8.decode(bytes));
    } on FormatException {
      proposal = null;
    }
    if (proposal == null) {
      response.statusCode = HttpStatus.badRequest;
      response.write('Check the source details and try again.');
      await response.close();
      return;
    }
    response.headers.contentType = ContentType.html;
    response.write(_phoneSuccess);
    await response.close();
    if (!_received.isCompleted) _received.complete(proposal);
    unawaited(close());
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _expiry.cancel();
    if (!_received.isCompleted) _received.complete(null);
    await _requests.cancel();
    await _server.close(force: true);
  }
}

const _phoneForm = '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Add a source to Tvium</title><style>
body{font:16px system-ui;background:#071725;color:#eef7ff;max-width:520px;margin:32px auto;padding:20px}
h1{font-size:28px}section{background:#123047;border:1px solid #436077;border-radius:18px;padding:20px;margin:20px 0}
label{display:block;margin:14px 0}input{box-sizing:border-box;width:100%;padding:12px;border-radius:10px;border:1px solid #6d8291;background:#071725;color:white}
button{background:#22c6ef;border:0;border-radius:10px;padding:13px 18px;font-weight:700}
p{color:#bdd0de}</style></head><body><h1>Add your playlist to Tvium</h1>
<p>Enter details on this phone, then confirm on your TV. Use a trusted home network; source details travel directly to the TV over that network.</p>
<section><h2>M3U URL</h2><form method="post"><input type="hidden" name="type" value="m3u">
<label>Playlist URL<input name="url" type="url" required autocomplete="off"></label><button type="submit">Send to TV</button></form></section>
<section><h2>Xtream Codes</h2><form method="post"><input type="hidden" name="type" value="xtream">
<label>Server URL<input name="server" type="url" required autocomplete="off"></label>
<label>Username<input name="username" required autocomplete="off"></label>
<label>Password<input name="password" type="password" required autocomplete="off"></label>
<button type="submit">Send to TV</button></form></section></body></html>''';

const _phoneSuccess = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="font:18px system-ui;background:#071725;color:#eef7ff;padding:32px"><h1>Sent to Tvium</h1><p>Confirm the source on your TV to finish.</p></body></html>''';
