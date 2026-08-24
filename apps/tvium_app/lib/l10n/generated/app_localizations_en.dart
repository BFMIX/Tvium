// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tvium';

  @override
  String get welcomeTitle => 'Welcome to Tvium';

  @override
  String get welcomeBody => 'Add your own IPTV source to get started.';

  @override
  String get disclaimer =>
      'Tvium does not provide TV channels, playlists or subscriptions.';

  @override
  String get m3uUrl => 'M3U URL';

  @override
  String get importLocalM3u => 'Import local M3U';

  @override
  String get xtreamCodes => 'Xtream Codes';

  @override
  String get comingLater => 'Coming later';

  @override
  String get urlHint => 'https://example.com/playlist.m3u';

  @override
  String get showPlaylistUrl => 'Show playlist URL';

  @override
  String get hidePlaylistUrl => 'Hide playlist URL';

  @override
  String get filePickerFailed => 'The playlist file could not be opened';

  @override
  String get analyzePlaylist => 'Analyze playlist';

  @override
  String get importing => 'Organizing your playlist…';

  @override
  String get cancel => 'Cancel';

  @override
  String itemsReady(int count) {
    return '$count items ready';
  }

  @override
  String get liveTv => 'LIVE TV';

  @override
  String get movies => 'MOVIES';

  @override
  String get tvShows => 'TV SHOWS';

  @override
  String get groups => 'Groups';

  @override
  String get all => 'All';

  @override
  String get noItems => 'No items found in this playlist';

  @override
  String get chooseChannel => 'Choose an item to start playback';

  @override
  String get importFailed => 'The playlist could not be imported';

  @override
  String get invalidUrl => 'Enter a valid HTTP or HTTPS playlist URL';

  @override
  String get unknownGroup => 'Unclassified';

  @override
  String get settings => 'Settings';

  @override
  String get search => 'Search';
}
