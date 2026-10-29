import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/library/category_manager_page.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  testWidgets('category manager stays compact on phone and TV viewports', (
    tester,
  ) async {
    for (final size in <Size>[const Size(390, 844), const Size(960, 540)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: CategoryManagerPage(
            profileId: 'home',
            repository: _CategoryRepository(),
            sources: const <IptvSource>[],
            onChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final content = find.byKey(const ValueKey('category-manager-content'));
      expect(content, findsOneWidget);
      expect(tester.getSize(content).width, lessThanOrEqualTo(900));
      expect(find.byType(SwitchListTile), findsNothing);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

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

  testWidgets('clearing search restores the complete category list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryManagerPage(
          profileId: 'home',
          repository: _CategoryRepository(),
          sources: const <IptvSource>[],
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('category-search-live')),
      'france',
    );
    await tester.pumpAndSettle();
    expect(find.text('US | Sports'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('US | Sports'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('category-search-live')))
          .controller
          ?.text,
      isEmpty,
    );
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
