import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';
import 'package:tvium_app/features/xtream/xtream_connection_service.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
  test(
    'stores credentials only after authentication and catalog load',
    () async {
      final backend = _MemorySecureKeyValueStore();
      final client = MockClient((request) async {
        final action = request.url.queryParameters['action'];
        if (action == null) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'user_info': <String, Object?>{
                'auth': 1,
                'status': 'Active',
                'is_trial': '0',
              },
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      });
      final service = DefaultXtreamConnectionService(
        httpClient: client,
        secretStore: SecureXtreamProfileStore(backend),
        random: Random(1),
      );

      final result = await service.addPlaylist(_input);

      expect(result.catalog.liveStreams, isEmpty);
      expect(backend.values, hasLength(1));
      expect(backend.values.keys.single, startsWith('tvium.xtream.profile.'));
      expect(service.toString(), isNot(contains('fixture-user')));
    },
  );

  test('does not store credentials when authentication fails', () async {
    final backend = _MemorySecureKeyValueStore();
    final service = DefaultXtreamConnectionService(
      httpClient: MockClient((_) async => http.Response('', 403)),
      secretStore: SecureXtreamProfileStore(backend),
      random: Random(1),
    );

    await expectLater(
      service.addPlaylist(_input),
      throwsA(
        isA<XtreamException>().having(
          (error) => error.failure,
          'failure',
          XtreamFailure.incorrectCredentials,
        ),
      ),
    );
    expect(backend.values, isEmpty);
  });
}

final _input = XtreamConnectionInput(
  profileName: 'Fixture',
  serverUri: Uri.parse('https://provider.example.test'),
  credentials: const XtreamCredentials(
    username: 'fixture-user',
    password: 'fixture-password',
  ),
);

final class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
