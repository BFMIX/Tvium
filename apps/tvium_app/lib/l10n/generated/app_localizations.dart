import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tvium'**
  String get appTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Tvium'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Add your own IPTV source to get started.'**
  String get welcomeBody;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Tvium does not provide TV channels, playlists or subscriptions.'**
  String get disclaimer;

  /// No description provided for @m3uUrl.
  ///
  /// In en, this message translates to:
  /// **'M3U URL'**
  String get m3uUrl;

  /// No description provided for @importLocalM3u.
  ///
  /// In en, this message translates to:
  /// **'Import local M3U'**
  String get importLocalM3u;

  /// No description provided for @xtreamCodes.
  ///
  /// In en, this message translates to:
  /// **'Xtream Codes'**
  String get xtreamCodes;

  /// No description provided for @comingLater.
  ///
  /// In en, this message translates to:
  /// **'Coming later'**
  String get comingLater;

  /// No description provided for @connectProvider.
  ///
  /// In en, this message translates to:
  /// **'Connect your provider'**
  String get connectProvider;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get profileName;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Show server URL'**
  String get showServerUrl;

  /// No description provided for @hideServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Hide server URL'**
  String get hideServerUrl;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @addPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add playlist'**
  String get addPlaylist;

  /// No description provided for @invalidXtreamFields.
  ///
  /// In en, this message translates to:
  /// **'Complete every field with a valid HTTP or HTTPS server URL'**
  String get invalidXtreamFields;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get connectionSuccessful;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'The connection could not be completed'**
  String get connectionFailed;

  /// No description provided for @incorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect username or password'**
  String get incorrectCredentials;

  /// No description provided for @networkTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond'**
  String get networkTimeout;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The server is currently unreachable'**
  String get serverUnreachable;

  /// No description provided for @invalidProviderResponse.
  ///
  /// In en, this message translates to:
  /// **'The provider returned an unsupported response'**
  String get invalidProviderResponse;

  /// No description provided for @xtreamPlaylistAdded.
  ///
  /// In en, this message translates to:
  /// **'Playlist added: {count} items'**
  String xtreamPlaylistAdded(int count);

  /// No description provided for @webSessionStorageNotice.
  ///
  /// In en, this message translates to:
  /// **'On the Web, connection details are kept for this browser session only.'**
  String get webSessionStorageNotice;

  /// No description provided for @urlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/playlist.m3u'**
  String get urlHint;

  /// No description provided for @showPlaylistUrl.
  ///
  /// In en, this message translates to:
  /// **'Show playlist URL'**
  String get showPlaylistUrl;

  /// No description provided for @hidePlaylistUrl.
  ///
  /// In en, this message translates to:
  /// **'Hide playlist URL'**
  String get hidePlaylistUrl;

  /// No description provided for @filePickerFailed.
  ///
  /// In en, this message translates to:
  /// **'The playlist file could not be opened'**
  String get filePickerFailed;

  /// No description provided for @analyzePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Analyze playlist'**
  String get analyzePlaylist;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Organizing your playlist…'**
  String get importing;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @itemsReady.
  ///
  /// In en, this message translates to:
  /// **'{count} items ready'**
  String itemsReady(int count);

  /// No description provided for @liveTv.
  ///
  /// In en, this message translates to:
  /// **'LIVE TV'**
  String get liveTv;

  /// No description provided for @movies.
  ///
  /// In en, this message translates to:
  /// **'MOVIES'**
  String get movies;

  /// No description provided for @tvShows.
  ///
  /// In en, this message translates to:
  /// **'TV SHOWS'**
  String get tvShows;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No items found in this playlist'**
  String get noItems;

  /// No description provided for @chooseChannel.
  ///
  /// In en, this message translates to:
  /// **'Choose an item to start playback'**
  String get chooseChannel;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'The playlist could not be imported'**
  String get importFailed;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS playlist URL'**
  String get invalidUrl;

  /// No description provided for @unknownGroup.
  ///
  /// In en, this message translates to:
  /// **'Unclassified'**
  String get unknownGroup;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
