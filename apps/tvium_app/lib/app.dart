import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_design_system/tvium_design_system.dart';

import 'features/artwork/artwork_reference_store.dart';
import 'features/home/home_screen.dart';
import 'features/import/local_playlist_picker.dart';
import 'features/import/playlist_import_controller.dart';
import 'features/import/playlist_import_provider.dart';
import 'features/library/library_bootstrap_controller.dart';
import 'features/metadata/metadata_gateway_client.dart';
import 'features/metadata/metadata_overlay_store.dart';
import 'features/updates/update_checker.dart';
import 'features/xtream/xtream_connection_service.dart';
import 'l10n/generated/app_localizations.dart';

final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  ],
);

final class TviumApp extends StatelessWidget {
  const TviumApp({
    this.importController,
    this.localPlaylistPicker,
    this.xtreamConnectionService,
    this.profileSourceRepository,
    this.artworkReferenceStore,
    this.metadataGatewayClient,
    this.metadataOverlayStore,
    this.metadataConsentStore,
    this.playbackEngineFactory,
    this.playbackViewBuilder,
    this.updateChecker,
    this.releaseTag,
    super.key,
  });

  final PlaylistImportController? importController;
  final LocalPlaylistPicker? localPlaylistPicker;
  final XtreamConnectionService? xtreamConnectionService;
  final ProfileSourceRepository? profileSourceRepository;
  final ArtworkReferenceStore? artworkReferenceStore;
  final MetadataGatewayClient? metadataGatewayClient;
  final MetadataOverlayStore? metadataOverlayStore;
  final MetadataConsentStore? metadataConsentStore;
  final PlaybackEngineFactory? playbackEngineFactory;
  final PlaybackViewBuilder? playbackViewBuilder;
  final UpdateChecker? updateChecker;
  final String? releaseTag;

  @override
  Widget build(BuildContext context) {
    final controller = importController;
    final picker = localPlaylistPicker;
    final xtreamService = xtreamConnectionService;
    return ProviderScope(
      overrides: [
        if (profileSourceRepository != null)
          libraryRepositoryProvider.overrideWith(
            (ref) async => profileSourceRepository!,
          ),
        if (artworkReferenceStore != null || profileSourceRepository != null)
          artworkReferenceStoreProvider.overrideWithValue(
            artworkReferenceStore ??
                ArtworkReferenceStore(MemoryArtworkKeyValueStore()),
          ),
        if (metadataGatewayClient != null)
          metadataGatewayProvider.overrideWithValue(metadataGatewayClient),
        if (metadataOverlayStore != null)
          metadataOverlayStoreProvider.overrideWithValue(metadataOverlayStore!),
        if (metadataConsentStore != null)
          metadataConsentStoreProvider.overrideWithValue(metadataConsentStore!),
        if (controller != null)
          playlistImportControllerProvider.overrideWith(
            (ref) => controller,
            disposeNotifier: false,
          ),
        if (picker != null)
          localPlaylistPickerProvider.overrideWithValue(picker),
        if (xtreamService != null)
          xtreamConnectionServiceProvider.overrideWithValue(xtreamService),
        if (playbackEngineFactory != null)
          playbackEngineFactoryProvider.overrideWithValue(
            playbackEngineFactory!,
          ),
        if (playbackViewBuilder != null)
          playbackViewBuilderProvider.overrideWithValue(playbackViewBuilder!),
        if (updateChecker != null)
          updateCheckerProvider.overrideWithValue(updateChecker!),
        if (releaseTag != null)
          installedReleaseTagProvider.overrideWithValue(releaseTag!),
      ],
      child: MaterialApp.router(
        title: 'Tvium',
        debugShowCheckedModeBanner: false,
        theme: TviumTheme.light(),
        darkTheme: TviumTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
