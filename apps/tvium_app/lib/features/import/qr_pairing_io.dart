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
  return selectQrPairingAddress([
    for (final interface in interfaces)
      for (final address in interface.addresses)
        (interfaceName: interface.name, address: address),
  ]);
}

/// Chooses a private Wi-Fi or Ethernet address reachable by a nearby phone.
/// VPN and virtual adapter addresses can be private but point to another LAN.
InternetAddress? selectQrPairingAddress(
  Iterable<({String interfaceName, InternetAddress address})> candidates,
) {
  for (final candidate in candidates) {
    final name = candidate.interfaceName.toLowerCase();
    if (!(name.startsWith('en') ||
        name.startsWith('eth') ||
        name.startsWith('wl'))) {
      continue;
    }
    final address = candidate.address;
    if (address.type != InternetAddressType.IPv4) continue;
    final bytes = address.rawAddress;
    if (bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168)) {
      return address;
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
  bool _acceptingPost = false;

  @override
  String get pairingUrl =>
      'http://${_server.address.address}:${_server.port}/pair/$_token';

  @override
  Future<QrPairingSubmission?> get submission => _received.future;

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final french =
        request.headers
            .value(HttpHeaders.acceptLanguageHeader)
            ?.toLowerCase()
            .startsWith('fr') ??
        false;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(
      HttpHeaders.contentLanguageHeader,
      french ? 'fr' : 'en',
    );
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
      response.write(_phonePage(french: french));
      await response.close();
      return;
    }
    if (request.method != 'POST' || _received.isCompleted || _acceptingPost) {
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
    _acceptingPost = true;
    try {
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
      if (_closed || _received.isCompleted) {
        response.statusCode = HttpStatus.gone;
        await response.close();
        return;
      }
      if (proposal == null) {
        response.statusCode = HttpStatus.badRequest;
        response.write(
          french
              ? 'Vérifiez les informations de la source et réessayez.'
              : 'Check the source details and try again.',
        );
        await response.close();
        return;
      }
      response.headers.contentType = ContentType.html;
      response.write(_phonePage(french: french, success: true));
      await response.close();
      _received.complete(proposal);
      unawaited(close());
    } finally {
      _acceptingPost = false;
    }
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

String _phonePage({required bool french, bool success = false}) {
  final lang = french ? 'fr' : 'en';
  final title = french ? 'Ajouter une source à Tvium' : 'Add a source to Tvium';
  final heading = success
      ? french
            ? 'Envoyé à Tvium'
            : 'Sent to Tvium'
      : french
      ? 'Ajouter une playlist à Tvium'
      : 'Add your playlist to Tvium';
  final intro = success
      ? french
            ? 'Confirmez la source sur votre TV pour terminer.'
            : 'Confirm the source on your TV to finish.'
      : french
      ? 'Saisissez votre source sur ce téléphone, puis confirmez-la sur votre TV. Utilisez uniquement un réseau domestique de confiance.'
      : 'Enter your source on this phone, then confirm it on your TV. Use a trusted home network only.';
  final send = french ? 'Envoyer à la TV' : 'Send to TV';
  return '''<!doctype html>
<html lang="$lang"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$title</title><style>$_phoneStyles</style></head>
<body><main><header><span class="mark" aria-hidden="true">▶</span><strong>Tvium</strong><span class="badge">${french ? 'Connexion locale' : 'Local pairing'}</span></header>
<div class="intro"><p class="eyebrow">${french ? 'VOTRE TV, VOTRE SOURCE' : 'YOUR TV, YOUR SOURCE'}</p><h1>$heading</h1><p>$intro</p></div>
${success ? '' : '''<section><h2>01 <span>M3U URL</span></h2><form method="post"><input type="hidden" name="type" value="m3u">
<label>${french ? 'URL de la playlist' : 'Playlist URL'}<input name="url" type="url" required autocomplete="off" inputmode="url"></label><button type="submit">$send</button></form></section>
<section><h2>02 <span>Xtream Codes</span></h2><form method="post"><input type="hidden" name="type" value="xtream">
<label>${french ? 'URL du serveur' : 'Server URL'}<input name="server" type="url" required autocomplete="off" inputmode="url"></label>
<label>${french ? 'Identifiant' : 'Username'}<input name="username" required autocomplete="off"></label>
<label>${french ? 'Mot de passe' : 'Password'}<input name="password" type="password" required autocomplete="off"></label>
<button type="submit">$send</button></form></section>'''}
<footer>${french ? 'Les informations sont envoyées directement à votre TV sur le réseau local. Ce transfert n’est pas chiffré.' : 'Details are sent directly to your TV on the local network. This transfer is not encrypted.'}</footer></main></body></html>''';
}

const _phoneStyles = '''
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(ellipse at 78% 0%,#16466a 0%,transparent 45%),linear-gradient(145deg,#05111d,#0b2437 65%,#07131f);color:#f3f8fd;font:16px system-ui,-apple-system,sans-serif}
main{width:min(100%,620px);margin:auto;padding:28px 20px 48px}header{display:flex;align-items:center;gap:9px;margin-bottom:48px}header strong{font-size:23px;letter-spacing:-.04em}.mark{color:#29cdf4;font-size:28px}.badge{margin-left:auto;border:1px solid #4e849d;border-radius:99px;padding:7px 11px;color:#bde7f3;font-size:12px}
.intro{margin-bottom:30px}.eyebrow{font-size:11px;letter-spacing:.26em;color:#48d9f7;font-weight:700}h1{font-size:clamp(32px,7vw,47px);line-height:1.08;letter-spacing:-.04em;margin:10px 0 15px}.intro>p:last-child{color:#c5d5e1;line-height:1.55;max-width:55ch}
section{background:#133047b8;border:1px solid #6395aa77;border-radius:22px;padding:22px;margin:15px 0;box-shadow:0 18px 50px #0003;backdrop-filter:blur(16px)}h2{font-size:14px;color:#54d8f5;margin:0 0 17px}h2 span{color:#f3f8fd;font-size:21px;margin-left:10px}label{display:block;color:#d7e8f1;font-size:14px;font-weight:600;margin:14px 0 4px}input{display:block;width:100%;min-height:48px;margin-top:8px;padding:12px 14px;border:1px solid #7794a2;border-radius:11px;background:#071927;color:#fff;font:16px system-ui;outline:none}input:focus-visible{border-color:#2bd7f6;box-shadow:0 0 0 3px #2bd7f633}button{min-height:48px;margin-top:18px;padding:12px 20px;background:#23cbed;border:0;border-radius:11px;color:#042033;font:700 15px system-ui;cursor:pointer}button:focus-visible{outline:3px solid #fff;outline-offset:3px}footer{color:#a9c3d2;font-size:13px;line-height:1.5;margin:26px 3px}''';
