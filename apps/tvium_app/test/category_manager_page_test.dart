import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/library/category_manager_page.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  testWidgets('search and bulk visibility affect only matching categories', (
    tester,
  ) async {
    final repository = _CategoryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerPage(
          profileId: 'home',
          repository: repository,
          sources: const <IptvSource>[],
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hide all (2)'), findsOneWidget);
    expect(find.text('Show matching (0)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('category-hide-all')));
    await tester.pumpAndSettle();
    expect(find.text('Hide all (0)'), findsOneWidget);
    expect(find.text('Show matching (2)'), findsOneWidget);
    expect(
      repository.categories.every((category) => !category.visible),
      isTrue,
    );

    await tester.enterText(
      find.byKey(const ValueKey('category-search-live')),
      'france',
    );
    await tester.pumpAndSettle();
    expect(find.text('FR | News'), findsOneWidget);
    expect(find.text('US | Sports'), findsNothing);
    expect(find.text('Show matching (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-show-matching')));
    await tester.pumpAndSettle();
    expect(repository.categories.first.visible, isTrue);
    expect(repository.categories.last.visible, isFalse);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repository.categories.first.visible, isFalse);
  });
}

final class _CategoryRepository implements CategoryVisibilityRepository {
  final categories = <CatalogCategory>[
    const CatalogCategory(
      sourceId: 'one',
      kind: MediaKind.live,
      groupName: 'FR | News',
      count: 3,
      visible: true,
    ),
    const CatalogCategory(
      sourceId: 'one',
      kind: MediaKind.live,
      groupName: 'US | Sports',
      count: 2,
      visible: true,
    ),
  ];

  @override
  Future<List<CatalogCategory>> categoriesForProfile(
    String profileId,
    MediaKind kind,
  ) async => categories.where((category) => category.kind == kind).toList();

  @override
  Future<void> setCategoryVisible({
    required String profileId,
    required String sourceId,
    required MediaKind kind,
    required String? groupName,
    required bool visible,
  }) async {
    final index = categories.indexWhere(
      (category) =>
          category.sourceId == sourceId &&
          category.kind == kind &&
          category.groupName == groupName,
    );
    final old = categories[index];
    categories[index] = CatalogCategory(
      sourceId: old.sourceId,
      kind: old.kind,
      groupName: old.groupName,
      count: old.count,
      visible: visible,
    );
  }

  @override
  Future<void> setCategoriesVisible({
    required String profileId,
    required List<CatalogCategory> categories,
    required bool visible,
  }) async {
    for (final category in categories) {
      await setCategoryVisible(
        profileId: profileId,
        sourceId: category.sourceId,
        kind: category.kind,
        groupName: category.groupName,
        visible: visible,
      );
    }
  }
}
