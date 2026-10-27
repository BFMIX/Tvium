import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../xtream/secure_xtream_profile_store.dart';

final artworkReferenceStoreProvider = Provider<ArtworkReferenceStore>(
  (ref) => ArtworkReferenceStore(),
);

final class MemoryArtworkKeyValueStore implements SecureKeyValueStore {
  final _values = <String, String>{};

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

/// Keeps artwork addresses outside searchable catalog rows. Addresses can
/// contain provider credentials, so they live with the other source secrets.
final class ArtworkReferenceStore {
  ArtworkReferenceStore([SecureKeyValueStore? backend])
    : _backend = backend ?? FlutterSecureKeyValueStore();

  final SecureKeyValueStore _backend;
  static const _chunkSize = 100;

  String _key(String sourceId) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(sourceId)) {
      throw ArgumentError.value(sourceId, 'sourceId');
    }
    return 'tvium.artwork.source.$sourceId';
  }

  Future<void> write(String sourceId, Map<String, Uri> references) async {
    final key = _key(sourceId);
    final previousCount =
        int.tryParse(await _backend.read('$key.count') ?? '') ?? 0;
    final items = references.entries.toList(growable: false);
    final chunkCount = (items.length + _chunkSize - 1) ~/ _chunkSize;
    for (var chunk = 0; chunk < chunkCount; chunk++) {
      final portion = items.skip(chunk * _chunkSize).take(_chunkSize);
      await _backend.write(
        '$key.$chunk',
        jsonEncode({
          for (final item in portion) item.key: item.value.toString(),
        }),
      );
    }
    await _backend.write('$key.count', chunkCount.toString());
    for (var chunk = chunkCount; chunk < previousCount; chunk++) {
      await _backend.delete('$key.$chunk');
    }
  }

  Future<Map<String, Uri>> read(String sourceId) async {
    final key = _key(sourceId);
    final count = int.tryParse(await _backend.read('$key.count') ?? '') ?? 0;
    if (count < 0 || count > 10000) return const {};
    final references = <String, Uri>{};
    for (var chunk = 0; chunk < count; chunk++) {
      final payload = await _backend.read('$key.$chunk');
      if (payload == null) continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) continue;
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is! String) continue;
          final uri = Uri.tryParse(value);
          if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
            references[entry.key] = uri;
          }
        }
      } on FormatException {
        continue;
      }
    }
    return references;
  }

  /// Scans persisted chunks while retaining only addresses needed on screen.
  Future<Map<String, Uri>> readSelected(
    String sourceId,
    Set<String> entryIds,
  ) async {
    if (entryIds.isEmpty) return const {};
    final key = _key(sourceId);
    final count = int.tryParse(await _backend.read('$key.count') ?? '') ?? 0;
    if (count < 0 || count > 10000) return const {};
    final references = <String, Uri>{};
    for (
      var chunk = 0;
      chunk < count && references.length < entryIds.length;
      chunk++
    ) {
      final payload = await _backend.read('$key.$chunk');
      if (payload == null) continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) continue;
        for (final id in entryIds) {
          final value = decoded[id];
          if (value is! String) continue;
          final uri = Uri.tryParse(value);
          if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
            references[id] = uri;
          }
        }
      } on FormatException {
        continue;
      }
    }
    return references;
  }

  Future<void> delete(String sourceId) async {
    final key = _key(sourceId);
    final count = int.tryParse(await _backend.read('$key.count') ?? '') ?? 0;
    for (var chunk = 0; chunk < count; chunk++) {
      await _backend.delete('$key.$chunk');
    }
    await _backend.delete('$key.count');
  }
}
