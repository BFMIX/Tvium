import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/artwork/artwork_reference_store.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';

final class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  test(
    'artwork references survive store recreation outside catalog rows',
    () async {
      final backend = _MemoryStore();
      final original = ArtworkReferenceStore(backend);
      await original.write('source-1', {
        'live:1': Uri.parse('https://images.example.test/logo.png'),
      });

      final restored = await ArtworkReferenceStore(backend).read('source-1');
      expect(restored['live:1']?.path, '/logo.png');
      expect(backend.values['tvium.artwork.source.source-1.count'], '1');

      await original.delete('source-1');
      expect(await original.read('source-1'), isEmpty);
    },
  );

  test(
    'large catalogs use bounded chunks and remove obsolete references',
    () async {
      final backend = _MemoryStore();
      final store = ArtworkReferenceStore(backend);
      await store.write('source-2', {
        for (var index = 0; index < 205; index++)
          'movie:$index': Uri.parse('https://images.example.test/$index.jpg'),
      });
      expect(backend.values['tvium.artwork.source.source-2.count'], '3');
      expect((await store.read('source-2')).length, 205);

      await store.write('source-2', {
        'movie:0': Uri.parse('https://images.example.test/0.jpg'),
      });
      expect((await store.read('source-2')).keys, ['movie:0']);
      expect(
        backend.values.containsKey('tvium.artwork.source.source-2.2'),
        isFalse,
      );
    },
  );
}
