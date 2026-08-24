import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tvium_design_system/tvium_design_system.dart';

import 'features/home/home_screen.dart';
import 'features/import/local_playlist_picker.dart';
import 'features/import/playlist_import_controller.dart';
import 'features/import/playlist_import_provider.dart';
import 'l10n/generated/app_localizations.dart';

final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  ],
);

final class TviumApp extends StatelessWidget {
  const TviumApp({this.importController, this.localPlaylistPicker, super.key});

  final PlaylistImportController? importController;
  final LocalPlaylistPicker? localPlaylistPicker;

  @override
  Widget build(BuildContext context) {
    final controller = importController;
    final picker = localPlaylistPicker;
    return ProviderScope(
      overrides: [
        if (controller != null)
          playlistImportControllerProvider.overrideWith(
            (ref) => controller,
            disposeNotifier: false,
          ),
        if (picker != null)
          localPlaylistPickerProvider.overrideWithValue(picker),
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
