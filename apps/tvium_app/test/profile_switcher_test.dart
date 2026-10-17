import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/library/library_bootstrap_controller.dart';
import 'package:tvium_app/features/profiles/profile_switcher.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  testWidgets('switches between profiles while keeping the menu simple', (
    tester,
  ) async {
    final repository = InMemoryProfileSourceRepository();
    var switchNotifications = 0;
    await repository.ensureDefaultProfile();
    await repository.createProfile('Kids');
    await tester.pumpWidget(
      _TestApp(
        repository: repository,
        onProfileChanged: () => switchNotifications++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Home'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Kids'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Kids'), findsOneWidget);
    expect((await repository.activeProfile()).displayName, 'Kids');
    expect(switchNotifications, 1);
  });

  testWidgets('creates a profile and activates it', (tester) async {
    final repository = InMemoryProfileSourceRepository();
    await tester.pumpWidget(_TestApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      ' Family ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Family'), findsOneWidget);
    expect((await repository.activeProfile()).displayName, 'Family');
  });
}

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.repository, this.onProfileChanged});

  final ProfileSourceRepository repository;
  final VoidCallback? onProfileChanged;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ProfileSwitcher(onProfileChanged: onProfileChanged),
        ),
      ),
    );
  }
}
