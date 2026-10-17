import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

FlutterSecureStorage createTviumSecureStorage() => const FlutterSecureStorage(
  webOptions: WebOptions(useSessionStorage: true),
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);

abstract interface class SecureKeyValueStore {
  Future<void> write(String key, String value);

  Future<String?> read(String key);

  Future<void> delete(String key);
}

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? createTviumSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  String toString() => 'FlutterSecureKeyValueStore(***)';
}

final class XtreamConnectionSecret {
  const XtreamConnectionSecret({
    required this.serverUri,
    required this.credentials,
  });

  final Uri serverUri;
  final XtreamCredentials credentials;

  @override
  String toString() => 'XtreamConnectionSecret(***)';
}

final class SecureXtreamProfileStore {
  SecureXtreamProfileStore([SecureKeyValueStore? backend])
    : _backend = backend ?? FlutterSecureKeyValueStore();

  static const String _keyPrefix = 'tvium.xtream.profile.';
  static final RegExp _validReference = RegExp(r'^[A-Za-z0-9_-]+$');

  final SecureKeyValueStore _backend;

  Future<void> write(String reference, XtreamConnectionSecret secret) async {
    final key = _keyFor(reference);
    final payload = jsonEncode(<String, String>{
      'serverUri': secret.serverUri.toString(),
      'username': secret.credentials.username,
      'password': secret.credentials.password,
    });
    await _backend.write(key, payload);
  }

  Future<XtreamConnectionSecret?> read(String reference) async {
    final payload = await _backend.read(_keyFor(reference));
    if (payload == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final serverValue = decoded['serverUri'];
      final username = decoded['username'];
      final password = decoded['password'];
      if (serverValue is! String ||
          username is! String ||
          password is! String) {
        throw const FormatException();
      }
      final serverUri = Uri.parse(serverValue);
      if (!serverUri.hasScheme || serverUri.host.isEmpty) {
        throw const FormatException();
      }
      return XtreamConnectionSecret(
        serverUri: serverUri,
        credentials: XtreamCredentials(username: username, password: password),
      );
    } on FormatException {
      throw const XtreamSecretStoreException();
    }
  }

  Future<void> delete(String reference) => _backend.delete(_keyFor(reference));

  String _keyFor(String reference) {
    if (!_validReference.hasMatch(reference)) {
      throw ArgumentError('Invalid secure profile reference.');
    }
    return '$_keyPrefix$reference';
  }

  @override
  String toString() => 'SecureXtreamProfileStore(***)';
}

final class XtreamSecretStoreException implements Exception {
  const XtreamSecretStoreException();

  @override
  String toString() => 'Xtream profile data is unavailable.';
}
