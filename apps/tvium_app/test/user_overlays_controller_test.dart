import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/library/library_bootstrap_controller.dart';
import 'package:tvium_app/features/library/user_overlays_controller.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  test(
    'loads only favorites and history owned by the requested profile',
    () async {
      final repository = InMemoryProfileSourceRepository();
      addTearDown(repository.close);
      const homeFavorite = MediaLocator(
        profileId: 'profile-home',
        sourceId: 'source-a',
        entryId: 'live:news',
      );
      const kidsFavorite = MediaLocator(
        profileId: 'profile-kids',
        sourceId: 'source-a',
        entryId: 'live:kids',
      );
      await repository.setFavorite(homeFavorite, isFavorite: true);
      await repository.setFavorite(kidsFavorite, isFavorite: true);
      await repository.recordPlayback(
        PlaybackHistoryEntry(
          media: homeFavorite,
          lastPlayedAtUtc: DateTime.utc(2026, 10, 18, 12),
          position: const Duration(minutes: 4),
          duration: const Duration(minutes: 30),
        ),
      );
      await repository.recordPlayback(
        PlaybackHistoryEntry(
          media: kidsFavorite,
          lastPlayedAtUtc: DateTime.utc(2026, 10, 18, 13),
          position: const Duration(minutes: 1),
          duration: const Duration(minutes: 10),
        ),
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      final snapshot = await container.read(
        userOverlaysControllerProvider('profile-home').future,
      );

      expect(snapshot.favorites, {homeFavorite});
      expect(snapshot.history.map((entry) => entry.media), [homeFavorite]);
      expect(snapshot.isFavorite(homeFavorite), isTrue);
      expect(snapshot.isFavorite(kidsFavorite), isFalse);
    },
  );

  test(
    'toggleFavorite persists the new value and updates visible state',
    () async {
      final repository = InMemoryProfileSourceRepository();
      addTearDown(repository.close);
      const media = MediaLocator(
        profileId: 'profile-home',
        sourceId: 'source-a',
        entryId: 'movie:42',
      );
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(
        userOverlaysControllerProvider('profile-home').future,
      );

      final controller = container.read(
        userOverlaysControllerProvider('profile-home').notifier,
      );
      await controller.toggleFavorite(media);

      expect(await repository.isFavorite(media), isTrue);
      expect(
        container
            .read(userOverlaysControllerProvider('profile-home'))
            .requireValue
            .favorites,
        {media},
      );

      await controller.toggleFavorite(media);

      expect(await repository.isFavorite(media), isFalse);
      expect(
        container
            .read(userOverlaysControllerProvider('profile-home'))
            .requireValue
            .favorites,
        isEmpty,
      );
    },
  );

  test('serializes rapid favorite toggles without losing an update', () async {
    final repository = InMemoryProfileSourceRepository();
    addTearDown(repository.close);
    const media = MediaLocator(
      profileId: 'profile-home',
      sourceId: 'source-a',
      entryId: 'movie:rapid',
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(userOverlaysControllerProvider('profile-home').future);
    final controller = container.read(
      userOverlaysControllerProvider('profile-home').notifier,
    );

    await Future.wait([
      controller.toggleFavorite(media),
      controller.toggleFavorite(media),
    ]);

    expect(await repository.isFavorite(media), isFalse);
    expect(
      container
          .read(userOverlaysControllerProvider('profile-home'))
          .requireValue
          .favorites,
      isEmpty,
    );
  });

  test(
    'recordPlayback exposes the latest profile history immediately',
    () async {
      final repository = InMemoryProfileSourceRepository();
      addTearDown(repository.close);
      const media = MediaLocator(
        profileId: 'profile-home',
        sourceId: 'source-a',
        entryId: 'episode:7',
      );
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(
        userOverlaysControllerProvider('profile-home').future,
      );
      final entry = PlaybackHistoryEntry(
        media: media,
        lastPlayedAtUtc: DateTime.utc(2026, 10, 18, 14),
        position: const Duration(minutes: 18),
        duration: const Duration(minutes: 48),
      );

      await container
          .read(userOverlaysControllerProvider('profile-home').notifier)
          .recordPlayback(entry);

      final snapshot = container
          .read(userOverlaysControllerProvider('profile-home'))
          .requireValue;
      expect(snapshot.history, hasLength(1));
      expect(snapshot.history.single.media, media);
      expect(snapshot.history.single.position, const Duration(minutes: 18));
    },
  );

  test('clearHistory removes only the active profile history', () async {
    final repository = InMemoryProfileSourceRepository();
    addTearDown(repository.close);
    const homeMedia = MediaLocator(
      profileId: 'profile-home',
      sourceId: 'source-a',
      entryId: 'live:home',
    );
    const kidsMedia = MediaLocator(
      profileId: 'profile-kids',
      sourceId: 'source-a',
      entryId: 'live:kids',
    );
    for (final media in [homeMedia, kidsMedia]) {
      await repository.recordPlayback(
        PlaybackHistoryEntry(
          media: media,
          lastPlayedAtUtc: DateTime.utc(2026, 10, 18, 15),
          position: Duration.zero,
          duration: const Duration(minutes: 10),
        ),
      );
    }
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(userOverlaysControllerProvider('profile-home').future);

    await container
        .read(userOverlaysControllerProvider('profile-home').notifier)
        .clearHistory();

    expect(
      container
          .read(userOverlaysControllerProvider('profile-home'))
          .requireValue
          .history,
      isEmpty,
    );
    expect(await repository.historyForProfile('profile-kids'), hasLength(1));
  });

  test(
    'saveParentalPolicy persists and exposes the active profile policy',
    () async {
      final repository = InMemoryProfileSourceRepository();
      addTearDown(repository.close);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(
        userOverlaysControllerProvider('profile-home').future,
      );
      const policy = ParentalPolicy(
        profileId: 'profile-home',
        pinDigest: 'tvium-pin-v1-fixture',
        blockedContent: {'adult'},
      );

      await container
          .read(userOverlaysControllerProvider('profile-home').notifier)
          .saveParentalPolicy(policy);

      expect(
        container
            .read(userOverlaysControllerProvider('profile-home'))
            .requireValue
            .parentalPolicy,
        same(policy),
      );
      expect(
        await repository.parentalPolicyForProfile('profile-home'),
        same(policy),
      );
    },
  );
}

ProviderContainer _container(InMemoryProfileSourceRepository repository) =>
    ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
