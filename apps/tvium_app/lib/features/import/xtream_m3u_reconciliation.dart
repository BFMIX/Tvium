import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

/// Conservative identity check before retiring an already saved M3U source.
/// Exact, unique title/kind pairs are required; uncertain catalogs remain M3U.
bool canReplaceSavedM3u(
  Iterable<PersistedMediaEntry> saved,
  XtreamCatalog catalog,
) {
  final entries = saved.toList(growable: false);
  if (entries.length < 3) return false;

  String key(String name, MediaKind kind) =>
      '${kind.name}\u0000${name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';

  final savedKeys = <String>{};
  for (final entry in entries) {
    if (entry.kind == MediaKind.unclassified ||
        entry.originalName.trim().isEmpty ||
        !savedKeys.add(key(entry.originalName, entry.kind))) {
      return false;
    }
  }

  final catalogKeys = <String>{};
  for (final item in [...catalog.liveStreams, ...catalog.movies]) {
    if (item.name.trim().isEmpty ||
        !catalogKeys.add(key(item.name, item.kind))) {
      return false;
    }
  }
  for (final series in catalog.series) {
    if (series.name.trim().isEmpty ||
        !catalogKeys.add(key(series.name, MediaKind.episode))) {
      return false;
    }
  }
  return catalogKeys.containsAll(savedKeys);
}
