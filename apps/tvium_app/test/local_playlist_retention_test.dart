import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/import/local_playlist_picker.dart';

void main() {
  test(
    'keeps a private managed copy after the selected file disappears',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'tvium_local_playlist_retention_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final selected = File('${temporaryDirectory.path}/selected.m3u');
      await selected.writeAsString(
        '#EXTM3U\n#EXTINF:-1,Fixture News\n'
        'https://stream.example.test/news.m3u8\n',
      );
      final managedRoot = Directory('${temporaryDirectory.path}/support');

      final retained = await retainLocalPlaylistFile(
        selected.path,
        supportDirectory: managedRoot,
      );
      await selected.delete();
      final lines = await retained.readLines().toList();

      expect(lines, contains('#EXTINF:-1,Fixture News'));
      expect(retained.path, startsWith(managedRoot.path));
      expect(retained.originalPath, selected.path);
    },
  );

  test('reuses one managed copy for identical playlist content', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'tvium_local_playlist_deduplication_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final first = File('${temporaryDirectory.path}/first.m3u');
    final second = File('${temporaryDirectory.path}/second.m3u');
    const content =
        '#EXTM3U\n#EXTINF:-1,Fixture\n'
        'https://stream.example.test/live.m3u8\n';
    await first.writeAsString(content);
    await second.writeAsString(content);
    final managedRoot = Directory('${temporaryDirectory.path}/support');

    final retainedFirst = await retainLocalPlaylistFile(
      first.path,
      supportDirectory: managedRoot,
    );
    final retainedSecond = await retainLocalPlaylistFile(
      second.path,
      supportDirectory: managedRoot,
    );

    expect(retainedSecond.path, retainedFirst.path);
    expect(
      Directory('${managedRoot.path}/playlists').listSync().whereType<File>(),
      hasLength(1),
    );
  });
}
