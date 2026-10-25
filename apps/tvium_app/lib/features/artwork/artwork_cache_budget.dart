import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'artwork_image.dart';

const artworkCacheMaxBytes = 256 * 1024 * 1024;

final class ArtworkCacheUsage {
  const ArtworkCacheUsage(this.key, this.bytes, this.lastUsed);

  final String key;
  final int bytes;
  final DateTime lastUsed;
}

final class ArtworkCacheStorage {
  const ArtworkCacheStorage({required this.entryCount, required this.bytes});

  final int entryCount;
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is ArtworkCacheStorage &&
      other.entryCount == entryCount &&
      other.bytes == bytes;

  @override
  int get hashCode => Object.hash(entryCount, bytes);
}

Future<List<ArtworkCacheUsage>> _scanArtworkCache(CacheManager cache) async {
  final repo = cache.config.repo;
  await repo.open();
  final entries = await repo.getAllObjects();
  final usage = <ArtworkCacheUsage>[];
  for (final entry in entries) {
    try {
      final file = await cache.config.fileSystem.createFile(entry.relativePath);
      if (!await file.exists()) continue;
      usage.add(
        ArtworkCacheUsage(
          entry.key,
          await file.length(),
          entry.touched ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    } on Object {
      // A missing or unreadable image does not affect other cache entries.
    }
  }
  return usage;
}

/// Returns native artwork usage without exposing stored image addresses.
Future<ArtworkCacheStorage?> readArtworkCacheStorage({
  CacheManager? cacheManager,
}) async {
  if (kIsWeb) return null;
  final usage = await _scanArtworkCache(cacheManager ?? artworkCache);
  return ArtworkCacheStorage(
    entryCount: usage.length,
    bytes: usage.fold<int>(0, (sum, entry) => sum + entry.bytes),
  );
}

/// Removes downloaded artwork only. Library entries and metadata stay saved.
Future<void> clearArtworkCache({CacheManager? cacheManager}) async {
  if (kIsWeb) return;
  final cache = cacheManager ?? artworkCache;
  final repo = cache.config.repo;
  await repo.open();
  for (final entry in await repo.getAllObjects()) {
    await cache.removeFile(entry.key);
  }
}

/// Chooses least recently used files without reading or logging image URLs.
List<String> artworkEvictionKeys(
  Iterable<ArtworkCacheUsage> entries, {
  required int maxBytes,
}) {
  final ordered = entries.toList()
    ..sort((a, b) {
      final byTime = a.lastUsed.compareTo(b.lastUsed);
      return byTime == 0 ? a.key.compareTo(b.key) : byTime;
    });
  var total = ordered.fold<int>(0, (sum, entry) => sum + entry.bytes);
  final evictions = <String>[];
  for (final entry in ordered) {
    if (total <= maxBytes) break;
    evictions.add(entry.key);
    total -= entry.bytes;
  }
  return evictions;
}

/// Trims native disk artwork on launch. Cache entries currently in memory may
/// remain visible, and missing files can be fetched again when online.
Future<void> pruneArtworkCache({
  CacheManager? cacheManager,
  int maxBytes = artworkCacheMaxBytes,
}) async {
  if (kIsWeb) return;
  final cache = cacheManager ?? artworkCache;
  try {
    final usage = await _scanArtworkCache(cache);
    for (final key in artworkEvictionKeys(usage, maxBytes: maxBytes)) {
      try {
        await cache.removeFile(key);
      } on Object {
        // Continue trimming other entries if one file is already gone.
      }
    }
  } on Object {
    // Cache maintenance is optional; library startup must remain usable.
  }
}
