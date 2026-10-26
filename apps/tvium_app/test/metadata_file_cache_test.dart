import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/metadata/metadata_cache_backend_io.dart';
import 'package:tvium_app/features/metadata/metadata_file_cache_io.dart';

void main() {
  test('macOS metadata reads use a local file cache', () {
    if (Platform.isMacOS) {
      expect(createMetadataCacheBackend(), isA<FileMetadataKeyValueStore>());
    }
  });

  test(
    'public metadata cache survives restart without Keychain access',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tvium-metadata-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final first = FileMetadataKeyValueStore(directory: directory);
      final key =
          'tvium.metadata.v1.${sha256.convert(utf8.encode('synthetic'))}';
      await first.write(key, '{"title":"Example"}');

      final restored = FileMetadataKeyValueStore(directory: directory);
      expect(await restored.read(key), '{"title":"Example"}');
      expect(directory.listSync().length, 1);
    },
  );

  test('public metadata cache rejects non-metadata keys', () async {
    final directory = await Directory.systemTemp.createTemp('tvium-metadata-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileMetadataKeyValueStore(directory: directory);

    expect(
      () => store.write('tvium.xtream.profile.synthetic', 'private'),
      throwsArgumentError,
    );
    expect(directory.listSync(), isEmpty);
  });
}
