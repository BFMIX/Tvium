import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
  test('round-trips an Xtream connection through the secure backend', () async {
    final backend = _MemorySecureKeyValueStore();
    final store = SecureXtreamProfileStore(backend);
    final secret = XtreamConnectionSecret(
      serverUri: Uri.parse('https://provider.example.test:8443'),
      credentials: const XtreamCredentials(
        username: 'fixture-user',
        password: 'fixture-password',
      ),
    );

    await store.write('profile-1', secret);
    final restored = await store.read('profile-1');

    expect(restored, isNotNull);
    expect(restored!.serverUri, secret.serverUri);
    expect(restored.credentials.username, 'fixture-user');
    expect(restored.credentials.password, 'fixture-password');
    expect(store.toString(), isNot(contains('fixture-user')));
    expect(store.toString(), isNot(contains('provider.example.test')));
  });

  test('deletes an Xtream connection from the secure backend', () async {
    final backend = _MemorySecureKeyValueStore();
    final store = SecureXtreamProfileStore(backend);
    await store.write(
      'profile-1',
      XtreamConnectionSecret(
        serverUri: Uri.parse('https://provider.example.test'),
        credentials: const XtreamCredentials(
          username: 'fixture-user',
          password: 'fixture-password',
        ),
      ),
    );

    await store.delete('profile-1');

    expect(await store.read('profile-1'), isNull);
  });

  test('reports corrupt secure data without exposing its contents', () async {
    final backend = _MemorySecureKeyValueStore();
    final store = SecureXtreamProfileStore(backend);
    backend.values['tvium.xtream.profile.profile-1'] =
        '{"password":"must-not-leak"}';

    Object? failure;
    try {
      await store.read('profile-1');
    } catch (error) {
      failure = error;
    }

    expect(failure, isA<XtreamSecretStoreException>());
    expect(failure.toString(), isNot(contains('must-not-leak')));
  });

  test('rejects unsafe profile references', () async {
    final store = SecureXtreamProfileStore(_MemorySecureKeyValueStore());

    expect(() => store.read('../profile'), throwsArgumentError);
  });
}

final class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
