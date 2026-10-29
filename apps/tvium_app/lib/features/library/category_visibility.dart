import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

/// A small lookup for loaded pages and search results. Source rows stay intact.
final class CategoryVisibilityIndex {
  CategoryVisibilityIndex(Iterable<CatalogCategory> categories)
    : _hidden = {
        for (final category in categories)
          if (!category.visible)
            (category.sourceId, category.kind, category.groupName),
      };

  final Set<(String, MediaKind, String?)> _hidden;

  bool allows(String sourceId, MediaKind kind, String? groupName) =>
      !_hidden.contains((sourceId, kind, groupName));

  List<T> filter<T>(
    Iterable<T> entries,
    String Function(T) sourceId,
    MediaKind Function(T) kind,
    String? Function(T) groupName,
  ) => entries
      .where((entry) => allows(sourceId(entry), kind(entry), groupName(entry)))
      .toList(growable: false);
}
