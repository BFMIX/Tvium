import 'package:file/file.dart' as file_api;
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/artwork/artwork_cache_budget.dart';

final class _MemoryCacheFiles implements FileSystem {
  final files = MemoryFileSystem();

  @override
  Future<file_api.File> createFile(String name) async => files.file(name);
}

final class _MemoryRepo extends Fake implements CacheInfoRepository {
  _MemoryRepo(this.entries);

  final Map<String, CacheObject> entries;

  @override
  Future<bool> open() async => true;

  @override
  Future<List<CacheObject>> getAllObjects() async => entries.values.toList();

  @override
  Future<CacheObject?> get(String key) async => entries[key];

  @override
  Future<int> update(CacheObject object, {bool setTouchedToNow = true}) async {
    entries[object.key] = object;
    return 1;
  }

  @override
  Future<CacheObject> updateOrInsert(CacheObject object) async {
    entries[object.key] = object;
    return object;
  }

  @override
  Future<int> deleteAll(Iterable<int> ids) async {
    final selected = ids.toSet();
    entries.removeWhere((_, object) => selected.contains(object.id));
    return selected.length;
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async => [];

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async => [];
}

void main() {
  test('evicts oldest artwork until the byte budget is met', () {
    final entries = [
      ArtworkCacheUsage('recent', 40, DateTime.utc(2026, 1, 3)),
      ArtworkCacheUsage('oldest', 70, DateTime.utc(2026, 1, 1)),
      ArtworkCacheUsage('middle', 50, DateTime.utc(2026, 1, 2)),
    ];

    expect(artworkEvictionKeys(entries, maxBytes: 100), ['oldest']);
    expect(artworkEvictionKeys(entries, maxBytes: 40), ['oldest', 'middle']);
  });

  test('a single oversized image is evicted and ties are deterministic', () {
    final touched = DateTime.utc(2026, 1, 1);
    expect(
      artworkEvictionKeys([
        ArtworkCacheUsage('b', 6, touched),
        ArtworkCacheUsage('a', 6, touched),
        ArtworkCacheUsage(
          'oversized',
          150,
          touched.subtract(const Duration(days: 1)),
        ),
      ], maxBytes: 6),
      ['oversized', 'a'],
    );
  });

  test(
    'native prune deletes older cached bytes through the cache manager',
    () async {
      final files = _MemoryCacheFiles();
      final repo = _MemoryRepo({
        for (var index = 0; index < 3; index++)
          'opaque-$index': CacheObject(
            'https://images.example.test/$index.jpg',
            key: 'opaque-$index',
            relativePath: 'art-$index.jpg',
            validTill: DateTime.utc(2027),
            id: index + 1,
            touched: DateTime.utc(2026, 1, index + 1),
          ),
      });
      for (var index = 0; index < 3; index++) {
        files.files.file('art-$index.jpg').writeAsBytesSync(List.filled(50, 0));
      }
      final cache = CacheManager(
        Config('synthetic-artwork', repo: repo, fileSystem: files),
      );

      await pruneArtworkCache(cacheManager: cache, maxBytes: 100);

      expect(await files.files.file('art-0.jpg').exists(), isFalse);
      expect(await files.files.file('art-1.jpg').exists(), isTrue);
      expect(await files.files.file('art-2.jpg').exists(), isTrue);
      expect(repo.entries.keys, isNot(contains('opaque-0')));
    },
  );

  test('reports actual cached bytes and clears only artwork entries', () async {
    final files = _MemoryCacheFiles();
    final repo = _MemoryRepo({
      'opaque-a': CacheObject(
        'https://images.example.test/a.jpg',
        key: 'opaque-a',
        relativePath: 'a.jpg',
        validTill: DateTime.utc(2027),
        id: 1,
      ),
      'opaque-b': CacheObject(
        'https://images.example.test/b.jpg',
        key: 'opaque-b',
        relativePath: 'b.jpg',
        validTill: DateTime.utc(2027),
        id: 2,
      ),
    });
    files.files.file('a.jpg').writeAsBytesSync(List.filled(12, 0));
    files.files.file('b.jpg').writeAsBytesSync(List.filled(18, 0));
    final cache = CacheManager(
      Config('synthetic-artwork-storage', repo: repo, fileSystem: files),
    );

    final before = await readArtworkCacheStorage(cacheManager: cache);
    expect(before, const ArtworkCacheStorage(entryCount: 2, bytes: 30));

    await clearArtworkCache(cacheManager: cache);

    expect(
      await readArtworkCacheStorage(cacheManager: cache),
      const ArtworkCacheStorage(entryCount: 0, bytes: 0),
    );
    expect(await files.files.file('a.jpg').exists(), isFalse);
    expect(await files.files.file('b.jpg').exists(), isFalse);
  });
}
