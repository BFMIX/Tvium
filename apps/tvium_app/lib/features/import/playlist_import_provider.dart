import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../library/library_bootstrap_controller.dart';
import '../sources/source_identity_service.dart';
import '../xtream/secure_xtream_profile_store.dart';
import 'm3u_import_persistence.dart';
import 'playlist_import_controller.dart';

final playlistImportControllerProvider =
    ChangeNotifierProvider<PlaylistImportController>((ref) {
      final secureBackend = FlutterSecureKeyValueStore();
      return PlaylistImportController(
        persistence: DefaultM3uImportPersistence(
          repositoryLoader: () => ref.read(libraryRepositoryProvider.future),
          secureStore: SecureM3uSourceStore(secureBackend),
          identityService: SourceIdentityService(secureBackend),
        ),
      );
    });

final m3uPlaybackResolverProvider = Provider<M3uPlaybackResolver>((ref) {
  return DefaultM3uPlaybackResolver(
    secureStore: SecureM3uSourceStore(FlutterSecureKeyValueStore()),
  );
});
