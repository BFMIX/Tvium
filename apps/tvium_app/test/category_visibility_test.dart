import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/library/category_visibility.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  test('hidden categories filter only their source and kind', () {
    final index = CategoryVisibilityIndex(<CatalogCategory>[
      const CatalogCategory(
        sourceId: 'first',
        kind: MediaKind.movie,
        groupName: 'France',
        count: 2,
        visible: false,
      ),
    ]);

    expect(index.allows('first', MediaKind.movie, 'France'), isFalse);
    expect(index.allows('second', MediaKind.movie, 'France'), isTrue);
    expect(index.allows('first', MediaKind.live, 'France'), isTrue);
    expect(index.allows('first', MediaKind.movie, 'Other'), isTrue);
    expect(
      index.filter(
        [
          ('first', MediaKind.movie, 'France'),
          ('second', MediaKind.movie, 'France'),
        ],
        (entry) => entry.$1,
        (entry) => entry.$2,
        (entry) => entry.$3,
      ),
      [('second', MediaKind.movie, 'France')],
    );
  });

  test('null group is independent of an empty named group', () {
    final index = CategoryVisibilityIndex(<CatalogCategory>[
      const CatalogCategory(
        sourceId: 'first',
        kind: MediaKind.live,
        groupName: null,
        count: 1,
        visible: false,
      ),
    ]);
    expect(index.allows('first', MediaKind.live, null), isFalse);
    expect(index.allows('first', MediaKind.live, ''), isTrue);
  });
}
