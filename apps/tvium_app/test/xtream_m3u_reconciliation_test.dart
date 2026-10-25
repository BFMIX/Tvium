import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/import/xtream_m3u_reconciliation.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
  test(
    'retains a saved M3U unless every distinct title and kind is present',
    () {
      final saved = [
        _entry('News One', MediaKind.live),
        _entry('Movie Two', MediaKind.movie),
        _entry('News Three', MediaKind.live),
      ];
      expect(
        canReplaceSavedM3u(
          saved,
          _catalog(['News One', 'News Three'], ['Movie Two']),
        ),
        isTrue,
      );
      expect(
        canReplaceSavedM3u(saved, _catalog(['News One'], ['Movie Two'])),
        isFalse,
      );
      expect(
        canReplaceSavedM3u(
          saved.take(2),
          _catalog(['News One'], ['Movie Two']),
        ),
        isFalse,
      );
      expect(
        canReplaceSavedM3u([
          ...saved,
          saved.first,
        ], _catalog(['News One', 'News Three'], ['Movie Two'])),
        isFalse,
      );
      expect(
        canReplaceSavedM3u(
          saved,
          _catalog(['News One', 'News One', 'News Three'], ['Movie Two']),
        ),
        isFalse,
      );
    },
  );
}

PersistedMediaEntry _entry(String name, MediaKind kind) => PersistedMediaEntry(
  id: name,
  playlistId: 'saved',
  sourceReference: 'saved',
  originalName: name,
  displayName: name,
  groupName: null,
  kind: kind,
);

XtreamCatalog _catalog(List<String> live, List<String> movies) => XtreamCatalog(
  liveCategories: const [],
  liveStreams: [for (final name in live) _item(name, MediaKind.live)],
  movieCategories: const [],
  movies: [for (final name in movies) _item(name, MediaKind.movie)],
  seriesCategories: const [],
  series: const [],
  warnings: const [],
);

XtreamMediaItem _item(String name, MediaKind kind) => XtreamMediaItem(
  id: name,
  name: name,
  categoryId: null,
  kind: kind,
  imageUri: null,
  containerExtension: null,
  epgChannelId: null,
);
