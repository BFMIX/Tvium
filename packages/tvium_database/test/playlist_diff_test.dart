import 'package:test/test.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  test('classifies added changed removed and unchanged entries', () {
    final previous = <PersistedMediaEntry>[
      _entry('same', displayName: 'Same'),
      _entry('changed', displayName: 'Old name'),
      _entry('removed', displayName: 'Removed'),
    ];
    final incoming = <PersistedMediaEntry>[
      _entry('same', displayName: 'Same'),
      _entry('changed', displayName: 'New name'),
      _entry('added', displayName: 'Added'),
    ];

    final diff = PlaylistDiff.calculate(previous: previous, incoming: incoming);

    expect(diff.added.map((entry) => entry.id), <String>['added']);
    expect(diff.changed.map((change) => change.before.id), <String>['changed']);
    expect(diff.changed.single.after.displayName, 'New name');
    expect(diff.removed.map((entry) => entry.id), <String>['removed']);
    expect(diff.unchanged.map((entry) => entry.id), <String>['same']);
  });

  test(
    'rejects duplicate identities instead of producing an ambiguous diff',
    () {
      final duplicate = _entry('duplicate', displayName: 'Duplicate');

      expect(
        () => PlaylistDiff.calculate(
          previous: const <PersistedMediaEntry>[],
          incoming: <PersistedMediaEntry>[duplicate, duplicate],
        ),
        throwsArgumentError,
      );
    },
  );

  test('refresh replaces the library only after a valid diff', () async {
    final repository = InMemoryPlaylistRepository();
    await repository.replaceEntries('primary', <PersistedMediaEntry>[
      _entry('existing', displayName: 'Existing'),
    ]);
    final synchronizer = PlaylistSynchronizer(repository);

    final result = await synchronizer.refresh('primary', <PersistedMediaEntry>[
      _entry('new', displayName: 'New'),
    ]);

    expect(result.added.single.id, 'new');
    expect(result.removed.single.id, 'existing');
    expect((await repository.entriesForPlaylist('primary')).single.id, 'new');
  });

  test('invalid refresh leaves the current library untouched', () async {
    final repository = InMemoryPlaylistRepository();
    final existing = _entry('existing', displayName: 'Existing');
    await repository.replaceEntries('primary', <PersistedMediaEntry>[existing]);
    final duplicate = _entry('duplicate', displayName: 'Duplicate');

    await expectLater(
      PlaylistSynchronizer(repository)
          .refresh('primary', <PersistedMediaEntry>[duplicate, duplicate]),
      throwsArgumentError,
    );

    expect(
      (await repository.entriesForPlaylist('primary')).single.id,
      'existing',
    );
  });
}

PersistedMediaEntry _entry(String id, {required String displayName}) {
  return PersistedMediaEntry(
    id: id,
    playlistId: 'primary',
    sourceReference: 'source-$id',
    originalName: id,
    displayName: displayName,
    groupName: 'News',
    kind: MediaKind.live,
  );
}
