import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../xtream/secure_xtream_profile_store.dart';

final class SourceIdentityService {
  SourceIdentityService(this.store);
  final SecureKeyValueStore store;
  Future<List<int>>? _keyFuture;
  Future<List<int>> _key() => _keyFuture ??= _loadKey();
  Future<List<int>> _loadKey() async {
    const keyName = 'tvium.source-identity.hmac-key';
    final existing = await store.read(keyName);
    if (existing != null) return base64Decode(existing);
    final random = Random.secure();
    final bytes = List.generate(32, (_) => random.nextInt(256));
    await store.write(keyName, base64Encode(bytes));
    return bytes;
  }

  Future<String> xtreamDigest(Uri uri, String username) async {
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError('Invalid provider address.');
    }
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    final canonical = uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          path: path,
        )
        .toString();
    return 'v1:${Hmac(sha256, await _key()).convert(utf8.encode(jsonEncode(['xtream', canonical, username.trim()])))}';
  }

  Future<String> m3uDigest(String kind, String canonicalLocation) async {
    if ((kind != 'url' && kind != 'file') || canonicalLocation.isEmpty) {
      throw ArgumentError('Invalid playlist identity.');
    }
    return 'v1:${Hmac(sha256, await _key()).convert(utf8.encode(jsonEncode(['m3u', kind, canonicalLocation])))}';
  }

  @override
  String toString() => 'SourceIdentityService(***)';
}
