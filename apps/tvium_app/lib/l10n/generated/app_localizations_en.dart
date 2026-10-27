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
  String get pairWithPhone => 'Add with your phone';

  @override
  String get orAddWithPhone => 'Or use your phone';

  @override
  String get pairingInstructions =>
      'Scan with a phone on the same trusted home network. The code expires after 10 minutes. Confirm the source here before importing.';

  @override
  String get pairingReceived =>
      'Source received. Confirm to add it to this TV.';

  @override
  String get pairingExpired =>
      'This pairing session has expired. Close this window and try again.';

  @override
  String get pairingUnavailable =>
      'Local pairing is unavailable. Connect this device to your home network and try again.';

  @override
  String get comingLater => 'Coming later';

  @override
  String get connectProvider => 'Connect your provider';

  @override
  String get profileName => 'Profile name';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get showServerUrl => 'Show server URL';

  @override
  String get hideServerUrl => 'Hide server URL';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get testConnection => 'Test connection';

  @override
  String get addPlaylist => 'Add playlist';

  @override
  String get invalidXtreamFields =>
      'Complete every field with a valid HTTP or HTTPS server URL';

  @override
  String get connectionSuccessful => 'Connection successful';

  @override
  String get connectionFailed => 'The connection could not be completed';

  @override
  String get incorrectCredentials => 'Incorrect username or password';

  @override
  String get networkTimeout => 'The server took too long to respond';

  @override
  String get xtreamConnecting => 'Connecting to the server...';

  @override
  String xtreamCatalogProgress(String section, int current, int total) {
    return 'Downloading $section ($current/$total)...';
  }

  @override
  String get xtreamLiveCategories => 'Live categories';

  @override
  String get xtreamLiveStreams => 'Live TV channels';

  @override
  String get xtreamVodCategories => 'movie categories';

  @override
  String get xtreamVodStreams => 'movies';

  @override
  String get xtreamSeriesCategories => 'series categories';

  @override
  String get xtreamSeries => 'TV series';

  @override
  String get xtreamSaving => 'Saving to the library...';

  @override
  String xtreamTimedOutAt(String section) {
    return 'The server timed out while downloading $section. Your existing library was kept.';
  }

  @override
  String get xtreamRetryExtended => 'Retry with a 2-minute limit';

  @override
  String get xtreamPartialAdded =>
      'Live TV was added. Some movie or series sections timed out and can be refreshed later.';

  @override
  String get serverUnreachable => 'The server is currently unreachable';

  @override
  String get invalidProviderResponse =>
      'The provider returned an unsupported response';

  @override
  String xtreamPlaylistAdded(int count) {
    return 'Playlist added: $count items';
  }

  @override
  String get webSessionStorageNotice =>
      'On the Web, connection details are kept for this browser session only.';

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
  String get savingPlaylist => 'Saving your library…';

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
  String get playbackUnavailable =>
      'Playback is unavailable. Reconnect this source and try again.';

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
