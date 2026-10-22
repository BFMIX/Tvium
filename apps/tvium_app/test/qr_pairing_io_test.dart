import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/import/qr_pairing.dart';
import 'package:tvium_app/features/import/qr_pairing_io.dart';

Future<String> sendToPairing(
  Uri address,
  String method,
  String path, [
  String? body,
]) async {
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    address.port,
  );
  final encoded = body == null ? <int>[] : utf8.encode(body);
  socket.write('$method $path HTTP/1.1\r\n');
  socket.write('Host: localhost\r\nConnection: close\r\n');
  if (body != null) {
    socket.write('Content-Type: application/x-www-form-urlencoded\r\n');
    socket.write('Content-Length: ${encoded.length}\r\n');
  }
  socket.write('\r\n');
  if (body != null) socket.add(encoded);
  await socket.flush();
  return utf8.decoder.bind(socket).join();
}

void main() {
  test('pairing prefers a physical LAN over a VPN or virtual adapter', () {
    final address = selectQrPairingAddress([
      (interfaceName: 'utun2', address: InternetAddress('10.8.0.2')),
      (interfaceName: 'bridge100', address: InternetAddress('192.168.64.1')),
      (interfaceName: 'en0', address: InternetAddress('192.168.1.25')),
    ]);
    expect(address?.address, '192.168.1.25');
  });

  test('pairing rejects a VPN-only or public address', () {
    final address = selectQrPairingAddress([
      (interfaceName: 'utun2', address: InternetAddress('10.8.0.2')),
      (interfaceName: 'en0', address: InternetAddress('203.0.113.10')),
    ]);
    expect(address, isNull);
  });

  test('pairing link contains no source and requires one-time token', () async {
    final session = await startQrPairing(
      bindAddress: InternetAddress.loopbackIPv4,
    );
    addTearDown(session.close);
    final address = Uri.parse(session.pairingUrl);
    expect(address.host, InternetAddress.loopbackIPv4.address);
    expect(address.pathSegments.last.length, greaterThanOrEqualTo(40));
    expect(session.pairingUrl, isNot(contains('playlist.example.test')));

    final missing = await sendToPairing(address, 'GET', '/pair/wrong');
    expect(missing, startsWith('HTTP/1.1 404'));
    final form = await sendToPairing(address, 'GET', address.path);
    expect(form, startsWith('HTTP/1.1 200'));
    expect(form, contains('Add your playlist to Tvium'));

    final posted = await sendToPairing(
      address,
      'POST',
      address.path,
      'type=m3u&url=https%3A%2F%2Fplaylist.example.test%2Flist.m3u',
    );
    expect(posted, startsWith('HTTP/1.1 200'));
    final received = await session.submission;
    expect(received, isA<QrM3uSubmission>());
    expect((received as QrM3uSubmission).url.host, 'playlist.example.test');
  });

  test('unused pairing closes after its lifetime', () async {
    final session = await startQrPairing(
      bindAddress: InternetAddress.loopbackIPv4,
      lifetime: const Duration(milliseconds: 20),
    );
    addTearDown(session.close);
    expect(await session.submission, isNull);
  });

  test('a second submission cannot replace an in-flight proposal', () async {
    final session = await startQrPairing(
      bindAddress: InternetAddress.loopbackIPv4,
    );
    addTearDown(session.close);
    final address = Uri.parse(session.pairingUrl);
    final firstBody =
        'type=m3u&url=https%3A%2F%2Ffirst.example.test%2Flist.m3u';
    final firstSocket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      address.port,
    );
    addTearDown(firstSocket.destroy);
    firstSocket.write('POST ${address.path} HTTP/1.1\r\n');
    firstSocket.write('Host: localhost\r\nConnection: close\r\n');
    firstSocket.write('Content-Type: application/x-www-form-urlencoded\r\n');
    firstSocket.write(
      'Content-Length: ${utf8.encode(firstBody).length}\r\n\r\n',
    );
    firstSocket.write(firstBody.substring(0, 10));
    await firstSocket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final second = await sendToPairing(
      address,
      'POST',
      address.path,
      'type=m3u&url=https%3A%2F%2Fsecond.example.test%2Flist.m3u',
    );
    expect(second, startsWith('HTTP/1.1 405'));

    firstSocket.write(firstBody.substring(10));
    await firstSocket.flush();
    final received = await session.submission;
    expect(received, isA<QrM3uSubmission>());
    expect((received as QrM3uSubmission).url.host, 'first.example.test');
  });

  test(
    'invalid form can be corrected within the same pairing session',
    () async {
      final session = await startQrPairing(
        bindAddress: InternetAddress.loopbackIPv4,
      );
      addTearDown(session.close);
      final address = Uri.parse(session.pairingUrl);
      final invalid = await sendToPairing(
        address,
        'POST',
        address.path,
        'type=m3u&url=not-a-url',
      );
      expect(invalid, startsWith('HTTP/1.1 400'));
      final corrected = await sendToPairing(
        address,
        'POST',
        address.path,
        'type=m3u&url=https%3A%2F%2Fplaylist.example.test%2Flist.m3u',
      );
      expect(corrected, startsWith('HTTP/1.1 200'));
      expect(await session.submission, isA<QrM3uSubmission>());
    },
  );
}
