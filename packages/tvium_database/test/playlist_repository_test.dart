import 'package:test/test.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  group('InMemoryPlaylistRepository', () {
    test('replaces one playlist without changing another', () async {
      final repository = InMemoryPlaylistRepository();
      await repository.replaceEntries('primary', <PersistedMediaEntry>[
        _entry(id: 'news', playlistId: 'primary', group: 'News'),
        _entry(id: 'film', playlistId: 'primary', group: 'Movies'),
      ]);
      await repository.replaceEntries('secondary', <PersistedMediaEntry>[
        _entry(id: 'sport', playlistId: 'secondary', group: 'Sports'),
      ]);

      await repository.replaceEntries('primary', <PersistedMediaEntry>[
        _entry(id: 'kids', playlistId: 'primary', group: 'Kids'),
      ]);

      expect(await repository.entriesForPlaylist('primary'), hasLength(1));
      expect(
        (await repository.entriesForPlaylist('secondary')).single.id,
        'sport',
      );
    });

    test('queries entries by their original group', () async {
      final repository = InMemoryPlaylistRepository();
      await repository.replaceEntries('primary', <PersistedMediaEntry>[
        _entry(id: 'one', playlistId: 'primary', group: 'News'),
        _entry(id: 'two', playlistId: 'primary', group: 'Sports'),
        _entry(id: 'three', playlistId: 'primary', group: 'News'),
      ]);

      final news = await repository.entriesForGroup('primary', 'News');

      expect(news.map((entry) => entry.id), <String>['one', 'three']);
    });
  });
}

PersistedMediaEntry _entry({
  required String id,
  required String playlistId,
  required String group,
}) {
  return PersistedMediaEntry(
    id: id,
    playlistId: playlistId,
    sourceReference: 'source-$id',
    originalName: id,
    displayName: id,
    groupName: group,
    kind: MediaKind.live,
  );
}
