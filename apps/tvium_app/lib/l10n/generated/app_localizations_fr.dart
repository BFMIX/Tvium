// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Tvium';

  @override
  String get welcomeTitle => 'Bienvenue dans Tvium';

  @override
  String get welcomeBody => 'Ajoutez votre propre source IPTV pour commencer.';

  @override
  String get disclaimer =>
      'Tvium ne fournit aucune chaîne, playlist ou abonnement TV.';

  @override
  String get m3uUrl => 'URL M3U';

  @override
  String get importLocalM3u => 'Importer un fichier M3U';

  @override
  String get xtreamCodes => 'Xtream Codes';

  @override
  String get pairWithPhone => 'Ajouter avec votre téléphone';

  @override
  String get orAddWithPhone => 'Ou utilisez votre téléphone';

  @override
  String get pairingInstructions =>
      'Scannez avec un téléphone sur le même réseau domestique de confiance. Le code expire après 10 minutes. Confirmez la source ici avant l’import.';

  @override
  String get pairingReceived =>
      'Source reçue. Confirmez pour l’ajouter à cette TV.';

  @override
  String get pairingExpired =>
      'Ce code a expiré. Fermez cette fenêtre et réessayez.';

  @override
  String get pairingUnavailable =>
      'Le jumelage local est indisponible. Connectez cet appareil à votre réseau domestique, puis réessayez.';

  @override
  String get comingLater => 'Prochainement';

  @override
  String get connectProvider => 'Connecter votre fournisseur';

  @override
  String get profileName => 'Nom du profil';

  @override
  String get serverUrl => 'URL du serveur';

  @override
  String get username => 'Identifiant';

  @override
  String get password => 'Mot de passe';

  @override
  String get showServerUrl => 'Afficher l’URL du serveur';

  @override
  String get hideServerUrl => 'Masquer l’URL du serveur';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get addPlaylist => 'Ajouter la playlist';

  @override
  String get invalidXtreamFields =>
      'Complétez tous les champs avec une URL de serveur HTTP ou HTTPS valide';

  @override
  String get connectionSuccessful => 'Connexion réussie';

  @override
  String get connectionFailed => 'La connexion n’a pas pu être établie';

  @override
  String get incorrectCredentials => 'Identifiant ou mot de passe incorrect';

  @override
  String get networkTimeout => 'Le serveur a mis trop de temps à répondre';

  @override
  String get xtreamConnecting => 'Connexion au serveur...';

  @override
  String xtreamCatalogProgress(String section, int current, int total) {
    return 'Téléchargement de $section ($current/$total)...';
  }

  @override
  String get xtreamLiveCategories => 'catégories TV';

  @override
  String get xtreamLiveStreams => 'chaînes Live';

  @override
  String get xtreamVodCategories => 'catégories de films';

  @override
  String get xtreamVodStreams => 'films';

  @override
  String get xtreamSeriesCategories => 'catégories de séries';

  @override
  String get xtreamSeries => 'séries TV';

  @override
  String get xtreamSaving => 'Enregistrement dans la bibliothèque...';

  @override
  String xtreamTimedOutAt(String section) {
    return 'Le serveur a expiré pendant le téléchargement de $section. La bibliothèque existante a été conservée.';
  }

  @override
  String get xtreamRetryExtended => 'Réessayer avec un délai de 2 minutes';

  @override
  String get xtreamPartialAdded =>
      'Les chaînes Live ont été ajoutées. Certaines sections films ou séries ont expiré et pourront être actualisées plus tard.';

  @override
  String get serverUnreachable => 'Le serveur est actuellement inaccessible';

  @override
  String get invalidProviderResponse =>
      'Le fournisseur a renvoyé une réponse non prise en charge';

  @override
  String xtreamPlaylistAdded(int count) {
    return 'Playlist ajoutée : $count éléments';
  }

  @override
  String get webSessionStorageNotice =>
      'Sur le Web, les informations de connexion sont conservées uniquement pendant cette session du navigateur.';

  @override
  String get urlHint => 'https://exemple.fr/playlist.m3u';

  @override
  String get showPlaylistUrl => 'Afficher l’URL de la playlist';

  @override
  String get hidePlaylistUrl => 'Masquer l’URL de la playlist';

  @override
  String get filePickerFailed =>
      'Le fichier de playlist n’a pas pu être ouvert';

  @override
  String get analyzePlaylist => 'Analyser la playlist';

  @override
  String get importing => 'Organisation de votre playlist…';

  @override
  String get savingPlaylist => 'Enregistrement de votre bibliothèque…';

  @override
  String get cancel => 'Annuler';

  @override
  String itemsReady(int count) {
    return '$count éléments prêts';
  }

  @override
  String get liveTv => 'LIVE TV';

  @override
  String get movies => 'FILMS';

  @override
  String get tvShows => 'SÉRIES TV';

  @override
  String get groups => 'Groupes';

  @override
  String get all => 'Tout';

  @override
  String get noItems => 'Aucun élément trouvé dans cette playlist';

  @override
  String get chooseChannel => 'Choisissez un élément pour lancer la lecture';

  @override
  String get playbackUnavailable =>
      'La lecture est indisponible. Reconnectez cette source puis réessayez.';

  @override
  String get importFailed => 'La playlist n’a pas pu être importée';

  @override
  String get invalidUrl => 'Saisissez une URL HTTP ou HTTPS valide';

  @override
  String get unknownGroup => 'Non classé';

  @override
  String get settings => 'Réglages';

  @override
  String get search => 'Rechercher';
}
