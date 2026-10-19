import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/sources/source_identity_service.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';

void main() {
  test('matches equivalent origins and trimmed usernames', () async {
    final service = SourceIdentityService(_MemorySecureKeyValueStore());

    final first = await service.xtreamDigest(
      Uri.parse('HTTPS://Provider.Example.Test:443/'),
      ' fixture-user ',
    );
    final second = await service.xtreamDigest(
      Uri.parse('https://provider.example.test'),
      'fixture-user',
    );

    expect(first, startsWith('v1:'));
    expect(second, first);
  });

  test('keeps distinct usernames separate and rejects URL secrets', () async {
    final service = SourceIdentityService(_MemorySecureKeyValueStore());
    final server = Uri.parse('https://provider.example.test');

    expect(
      await service.xtreamDigest(server, 'fixture-user-a'),
      isNot(await service.xtreamDigest(server, 'fixture-user-b')),
    );
    expect(
      () => service.xtreamDigest(
        Uri.parse('https://provider.example.test?password=fixture'),
        'fixture-user',
      ),
      throwsArgumentError,
    );
  });
}

final class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
