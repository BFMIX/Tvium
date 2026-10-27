import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_core/tvium_core.dart';
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
    this.catalogTotals = const {},
  });
  final UserProfile activeProfile;
  final List<UserProfile> profiles;
  final List<IptvSource> sources;
  final List<PersistedMediaEntry> entries;
  final Map<String, Map<String, Uri>> artwork;
  final Map<MediaKind, int> catalogTotals;
}

const libraryPageSize = 120;

Future<List<PersistedMediaEntry>> readCatalogPage(
  PagedProfileSourceRepository repository,
  List<IptvSource> sources,
  MediaKind kind, {
  required int offset,
  int limit = libraryPageSize,
}) async {
  var remainingOffset = offset;
  final result = <PersistedMediaEntry>[];
  for (final source in sources) {
    final count = await repository.countEntriesForPlaylist(source.id, kind);
    if (remainingOffset >= count) {
      remainingOffset -= count;
      continue;
    }
    final batch = await repository.entriesPageForPlaylist(
      source.id,
      kind,
      offset: remainingOffset,
      limit: limit - result.length,
    );
    result.addAll(batch);
    remainingOffset = 0;
    if (result.length >= limit) break;
  }
  return result;
}

final libraryBootstrapProvider = FutureProvider<LibrarySnapshot>((ref) async {
  final repository = await ref.watch(libraryRepositoryProvider.future);
  final active = await repository.ensureDefaultProfile();
  final sources = await repository.sourcesForProfile(active.id);
  final entries = <PersistedMediaEntry>[];
  final totals = <MediaKind, int>{};
  final artwork = <String, Map<String, Uri>>{};
  final artworkStore = ref.read(artworkReferenceStoreProvider);
  for (final source in sources) {
    if (repository is! PagedProfileSourceRepository) {
      entries.addAll(await repository.entriesForPlaylist(source.id));
    }
  }
  if (repository is PagedProfileSourceRepository) {
    final pagedRepository = repository as PagedProfileSourceRepository;
    for (final kind in MediaKind.values) {
      var count = 0;
      for (final source in sources) {
        count += await pagedRepository.countEntriesForPlaylist(source.id, kind);
      }
      totals[kind] = count;
      entries.addAll(
        await readCatalogPage(pagedRepository, sources, kind, offset: 0),
      );
    }
  }
  for (final source in sources) {
    try {
      // Keep the first frame independent of large secure-storage scans.
      artwork[source.id] = totals.values.fold<int>(0, (a, b) => a + b) > 1000
          ? const {}
          : await artworkStore.readSelected(
              source.id,
              entries
                  .where((entry) => entry.playlistId == source.id)
                  .map((entry) => entry.id)
                  .toSet(),
            );
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
    catalogTotals: totals,
  );
});
