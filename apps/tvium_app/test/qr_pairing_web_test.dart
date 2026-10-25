import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/features/home/home_screen.dart';
import 'package:tvium_app/features/import/qr_pairing.dart';
import 'package:tvium_app/features/import/qr_pairing_web.dart';
import 'package:tvium_app/l10n/generated/app_localizations_en.dart';

void main() {
  test('Web pairing instructions do not require a shared home network', () {
    final strings = AppLocalizationsEn();
    expect(
      pairingInstructionsForPlatform(strings, isWeb: true),
      contains('Scan the code with your phone'),
    );
    expect(
      pairingInstructionsForPlatform(strings, isWeb: true),
      isNot(contains('same trusted home network')),
    );
    expect(
      pairingInstructionsForPlatform(strings, isWeb: false),
      contains('same trusted home network'),
    );
    expect(
      pairingUnavailableForPlatform(strings, isWeb: true),
      contains('try again'),
    );
    expect(
      pairingUnavailableForPlatform(strings, isWeb: true),
      isNot(contains('home network')),
    );
  });

  test('Web shows pairing only when a secure relay is configured', () {
    expect(shouldShowQrPairing(isWeb: false, relay: ''), isTrue);
    expect(shouldShowQrPairing(isWeb: true, relay: ''), isFalse);
    expect(
      shouldShowQrPairing(isWeb: true, relay: 'http://relay.example.test'),
      isFalse,
    );
    expect(
      shouldShowQrPairing(isWeb: true, relay: 'https://relay.example.test'),
      isTrue,
    );
  });
  test('Web pairing requires an HTTPS relay outside loopback', () {
    expect(resolveWebPairingRelay('http://relay.example.test'), isNull);
    expect(resolveWebPairingRelay('https://user@relay.example.test'), isNull);
    expect(
      resolveWebPairingRelay('https://relay.example.test'),
      Uri.parse('https://relay.example.test'),
    );
  });

  test(
    'Web pairing receives a phone source without exposing it to relay',
    () async {
      const id = 'abcdefghijklmnopqrstuv';
      final viewerToken = 'v' * 43;
      final submitToken = 's' * 43;
      String? key;
      var deleted = false;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/v1/pairing') {
          expect(request.body, isEmpty);
          return http.Response(
            jsonEncode({
              'id': id,
              'viewerToken': viewerToken,
              'submitToken': submitToken,
              'expiresInSeconds': 600,
            }),
            201,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/v1/pairing/$id/submission') {
          expect(request.headers['Authorization'], 'Bearer $viewerToken');
          final keyBytes = base64Url.decode(base64Url.normalize(key!));
          final box = await AesGcm.with256bits().encrypt(
            utf8.encode(
              'type=m3u&url=https%3A%2F%2Fplaylist.example.test%2Flist.m3u',
            ),
            secretKey: SecretKey(keyBytes),
            nonce: List<int>.filled(12, 7),
          );
          String encode(List<int> bytes) =>
              base64UrlEncode(bytes).replaceAll('=', '');
          return http.Response(
            jsonEncode({
              'iv': encode(box.nonce),
              'ciphertext': encode([...box.cipherText, ...box.mac.bytes]),
            }),
            200,
          );
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/v1/pairing/$id') {
          expect(request.headers['Authorization'], 'Bearer $viewerToken');
          deleted = true;
          return http.Response('', 204);
        }
        return http.Response('', 404);
      });

      final session = await startQrPairing(
        relay: Uri.parse('https://relay.example.test'),
        client: client,
        pollInterval: const Duration(milliseconds: 20),
      );
      final qr = Uri.parse(session.pairingUrl);
      expect(qr.path, '/pair/');
      expect(session.pairingUrl, isNot(contains('playlist.example.test')));
      final fragment = Uri.splitQueryString(qr.fragment);
      expect(fragment['id'], id);
      expect(fragment['submit'], submitToken);
      key = fragment['key'];
      expect(base64Url.decode(base64Url.normalize(key!)), hasLength(32));
      final submission = await session.submission.timeout(
        const Duration(seconds: 2),
      );
      expect(submission, isA<QrM3uSubmission>());
      expect((submission as QrM3uSubmission).url.host, 'playlist.example.test');
      await session.close();
      expect(deleted, isTrue);
    },
  );

  test(
    'Web pairing rejects a tampered proposal without waiting for expiry',
    () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 'abcdefghijklmnopqrstuv',
              'viewerToken': 'v' * 43,
              'submitToken': 's' * 43,
            }),
            201,
          );
        }
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'iv': base64UrlEncode(List<int>.filled(12, 1)),
              'ciphertext': base64UrlEncode(List<int>.filled(17, 1)),
            }),
            200,
          );
        }
        return http.Response('', 204);
      });
      final session = await startQrPairing(
        relay: Uri.parse('https://relay.example.test'),
        client: client,
        pollInterval: const Duration(milliseconds: 20),
      );
      expect(
        await session.submission.timeout(const Duration(seconds: 2)),
        isNull,
      );
      await session.close();
    },
  );
}
