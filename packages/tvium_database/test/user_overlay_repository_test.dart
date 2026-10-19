import 'dart:io';

import 'package:test/test.dart';
import 'package:tvium_database/tvium_database.dart';

void main() {
  group('InMemoryProfileSourceRepository overlays', () {
    _sharedOverlayContract(() async => InMemoryProfileSourceRepository());
  });

  group('SqlitePlaylistRepository overlays', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'tvium_user_overlay_test_',
      );
    });

    tearDown(() => temporaryDirectory.delete(recursive: true));

    _sharedOverlayContract(
      () async => SqlitePlaylistRepository.open(
        '${temporaryDirectory.path}/library.sqlite',
      ),
    );

    test(
      'keeps favorites, history, and parental policy after reopening',
      () async {
        final path = '${temporaryDirectory.path}/library.sqlite';
        final repository = SqlitePlaylistRepository.open(path);
        final profile = await repository.ensureDefaultProfile();
        final media = MediaLocator(
          profileId: profile.id,
          sourceId: 'source-1',
          entryId: 'movie-1',
        );
        await repository.setFavorite(media, isFavorite: true);
        await repository.recordPlayback(
          PlaybackHistoryEntry(
            media: media,
            lastPlayedAtUtc: DateTime.utc(2026, 10, 17, 12),
            position: const Duration(minutes: 12),
            duration: const Duration(minutes: 90),
          ),
        );
        await repository.saveParentalPolicy(
          ParentalPolicy(
            profileId: profile.id,
            pinDigest: 'v1:fixture-digest',
            blockedContent: const {'adult'},
          ),
        );
        await repository.close();

        final reopened = SqlitePlaylistRepository.open(path);
        addTearDown(reopened.close);

        expect(await reopened.isFavorite(media), isTrue);
        expect(
          (await reopened.historyForProfile(profile.id)).single.position,
          const Duration(minutes: 12),
        );
        expect(
          (await reopened.parentalPolicyForProfile(profile.id))?.blockedContent,
          {'adult'},
        );
      },
    );
  });
}

void _sharedOverlayContract(
  Future<UserOverlayRepository> Function() createRepository,
) {
  test('adds and removes a favorite without duplicating it', () async {
    final repository = await createRepository();
    addTearDown(repository.close);
    final media = const MediaLocator(
      profileId: 'profile-1',
      sourceId: 'source-1',
      entryId: 'live-1',
    );

    await repository.setFavorite(media, isFavorite: true);
    await repository.setFavorite(media, isFavorite: true);

    expect(await repository.isFavorite(media), isTrue);
    expect(await repository.favoritesForProfile('profile-1'), [media]);

    await repository.setFavorite(media, isFavorite: false);
    expect(await repository.isFavorite(media), isFalse);
  });

  test('updates recent playback and orders history newest first', () async {
    final repository = await createRepository();
    addTearDown(repository.close);
    const first = MediaLocator(
      profileId: 'profile-1',
      sourceId: 'source-1',
      entryId: 'movie-1',
    );
    const second = MediaLocator(
      profileId: 'profile-1',
      sourceId: 'source-1',
      entryId: 'episode-1',
    );

    await repository.recordPlayback(
      PlaybackHistoryEntry(
        media: first,
        lastPlayedAtUtc: DateTime.utc(2026, 10, 17, 10),
        position: const Duration(minutes: 4),
        duration: const Duration(minutes: 80),
      ),
    );
    await repository.recordPlayback(
      PlaybackHistoryEntry(
        media: second,
        lastPlayedAtUtc: DateTime.utc(2026, 10, 17, 11),
        position: const Duration(minutes: 20),
        duration: const Duration(minutes: 45),
      ),
    );
    await repository.recordPlayback(
      PlaybackHistoryEntry(
        media: first,
        lastPlayedAtUtc: DateTime.utc(2026, 10, 17, 12),
        position: const Duration(minutes: 16),
        duration: const Duration(minutes: 80),
      ),
    );

    final history = await repository.historyForProfile('profile-1');
    expect(history.map((entry) => entry.media.entryId), [
      'movie-1',
      'episode-1',
    ]);
    expect(history.first.position, const Duration(minutes: 16));
  });

  test(
    'stores only a digest and replaces parental policy atomically',
    () async {
      final repository = await createRepository();
      addTearDown(repository.close);

      await repository.saveParentalPolicy(
        const ParentalPolicy(
          profileId: 'profile-1',
          pinDigest: 'v1:first-digest',
          blockedContent: {'adult', 'explicit'},
        ),
      );
      await repository.saveParentalPolicy(
        const ParentalPolicy(
          profileId: 'profile-1',
          pinDigest: 'v1:replacement-digest',
          blockedContent: {'adult'},
        ),
      );

      final policy = await repository.parentalPolicyForProfile('profile-1');
      expect(policy?.pinDigest, 'v1:replacement-digest');
      expect(policy?.blockedContent, {'adult'});
    },
  );
}
