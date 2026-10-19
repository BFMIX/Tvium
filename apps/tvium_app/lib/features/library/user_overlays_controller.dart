import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_database/tvium_database.dart';

import 'library_bootstrap_controller.dart';

final class UserOverlaySnapshot {
  UserOverlaySnapshot({
    required this.profileId,
    required Set<MediaLocator> favorites,
    required List<PlaybackHistoryEntry> history,
    required this.parentalPolicy,
  }) : favorites = Set.unmodifiable(favorites),
       history = List.unmodifiable(history);

  final String profileId;
  final Set<MediaLocator> favorites;
  final List<PlaybackHistoryEntry> history;
  final ParentalPolicy? parentalPolicy;

  bool isFavorite(MediaLocator media) => favorites.contains(media);

  UserOverlaySnapshot copyWith({
    Set<MediaLocator>? favorites,
    List<PlaybackHistoryEntry>? history,
    ParentalPolicy? parentalPolicy,
    bool replaceParentalPolicy = false,
  }) => UserOverlaySnapshot(
    profileId: profileId,
    favorites: favorites ?? this.favorites,
    history: history ?? this.history,
    parentalPolicy: replaceParentalPolicy
        ? parentalPolicy
        : this.parentalPolicy,
  );
}

final userOverlaysControllerProvider =
    AsyncNotifierProvider.family<
      UserOverlaysController,
      UserOverlaySnapshot,
      String
    >(UserOverlaysController.new);

final class UserOverlaysController extends AsyncNotifier<UserOverlaySnapshot> {
  UserOverlaysController(this.profileId);

  final String profileId;
  Future<void> _favoriteMutationQueue = Future<void>.value();

  @override
  Future<UserOverlaySnapshot> build() async {
    final repository = await _repository();
    return UserOverlaySnapshot(
      profileId: profileId,
      favorites: (await repository.favoritesForProfile(profileId)).toSet(),
      history: await repository.historyForProfile(profileId),
      parentalPolicy: await repository.parentalPolicyForProfile(profileId),
    );
  }

  Future<void> toggleFavorite(MediaLocator media) {
    _requireOwnedByProfile(media);
    final operation = _favoriteMutationQueue.then(
      (_) => _toggleFavoriteNow(media),
      onError: (Object _, StackTrace _) => _toggleFavoriteNow(media),
    );
    _favoriteMutationQueue = operation;
    return operation;
  }

  Future<void> _toggleFavoriteNow(MediaLocator media) async {
    final current = await future;
    final isFavorite = !current.isFavorite(media);
    await (await _repository()).setFavorite(media, isFavorite: isFavorite);
    final favorites = current.favorites.toSet();
    if (isFavorite) {
      favorites.add(media);
    } else {
      favorites.remove(media);
    }
    state = AsyncData(current.copyWith(favorites: favorites));
  }

  Future<void> recordPlayback(PlaybackHistoryEntry entry) async {
    _requireOwnedByProfile(entry.media);
    await future;
    final repository = await _repository();
    await repository.recordPlayback(entry);
    state = AsyncData(
      UserOverlaySnapshot(
        profileId: profileId,
        favorites: state.requireValue.favorites,
        history: await repository.historyForProfile(profileId),
        parentalPolicy: state.requireValue.parentalPolicy,
      ),
    );
  }

  Future<void> clearHistory() async {
    final current = await future;
    await (await _repository()).clearHistory(profileId);
    state = AsyncData(current.copyWith(history: const []));
  }

  Future<void> saveParentalPolicy(ParentalPolicy policy) async {
    if (policy.profileId != profileId) {
      throw ArgumentError.value(
        policy.profileId,
        'policy.profileId',
        'Must match the active overlay profile.',
      );
    }
    final current = await future;
    await (await _repository()).saveParentalPolicy(policy);
    state = AsyncData(
      current.copyWith(parentalPolicy: policy, replaceParentalPolicy: true),
    );
  }

  Future<UserOverlayRepository> _repository() async {
    final repository = await ref.read(libraryRepositoryProvider.future);
    if (repository case final UserOverlayRepository overlays) {
      return overlays;
    }
    throw StateError('The library repository does not support user overlays.');
  }

  void _requireOwnedByProfile(MediaLocator media) {
    if (media.profileId != profileId) {
      throw ArgumentError.value(
        media.profileId,
        'media.profileId',
        'Must match the active overlay profile.',
      );
    }
  }
}
