import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_database/tvium_database.dart';

import '../artwork/artwork_reference_store.dart';
import 'session_library_repository.dart'
    if (dart.library.io) 'native_library_repository.dart';

final libraryRepositoryProvider = FutureProvider<ProfileSourceRepository>((
  ref,
) async {
  final repository = await openLibraryRepository();
  ref.onDispose(repository.close);
  return repository;
});

final class LibrarySnapshot {
  const LibrarySnapshot({
    required this.activeProfile,
    required this.profiles,
    required this.sources,
    required this.entries,
    this.artwork = const {},
  });
  final UserProfile activeProfile;
  final List<UserProfile> profiles;
  final List<IptvSource> sources;
  final List<PersistedMediaEntry> entries;
  final Map<String, Map<String, Uri>> artwork;
}

final libraryBootstrapProvider = FutureProvider<LibrarySnapshot>((ref) async {
  final repository = await ref.watch(libraryRepositoryProvider.future);
  final active = await repository.ensureDefaultProfile();
  final sources = await repository.sourcesForProfile(active.id);
  final entries = <PersistedMediaEntry>[];
  final artwork = <String, Map<String, Uri>>{};
  final artworkStore = ref.read(artworkReferenceStoreProvider);
  for (final source in sources) {
    entries.addAll(await repository.entriesForPlaylist(source.id));
    try {
      artwork[source.id] = await artworkStore.read(source.id);
    } on Object {
      artwork[source.id] = const {};
    }
  }
  return LibrarySnapshot(
    activeProfile: active,
    profiles: await repository.profiles(),
    sources: sources,
    entries: entries,
    artwork: artwork,
  );
});
