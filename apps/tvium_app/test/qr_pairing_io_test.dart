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
}
