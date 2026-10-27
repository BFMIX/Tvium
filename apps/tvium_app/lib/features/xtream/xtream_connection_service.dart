import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

import '../artwork/artwork_reference_store.dart';
import '../library/library_bootstrap_controller.dart';
import '../sources/source_identity_service.dart';
import 'secure_xtream_profile_store.dart';

final xtreamConnectionServiceProvider = Provider<XtreamConnectionService>((
  ref,
) {
  final service = DefaultXtreamConnectionService(
    repositoryLoader: () => ref.read(libraryRepositoryProvider.future),
    identityService: SourceIdentityService(FlutterSecureKeyValueStore()),
  );
  ref.onDispose(service.close);
  return service;
});

final class XtreamConnectionInput {
  const XtreamConnectionInput({
    required this.profileName,
    required this.serverUri,
    required this.credentials,
  });

  final String profileName;
  final Uri serverUri;
  final XtreamCredentials credentials;

  @override
  String toString() => 'XtreamConnectionInput(***)';
}

final class XtreamAddedProfile {
  const XtreamAddedProfile({
    required this.profileId,
    required this.account,
    required this.catalog,
    this.targetProfileId,
    this.wasExisting = false,
    this.wasAlreadyLinked = false,
  });

  final String profileId;
  final XtreamAccountInfo account;
  final XtreamCatalog catalog;
  final String? targetProfileId;
  String get sourceId => profileId;
  final bool wasExisting;
  final bool wasAlreadyLinked;

  int get itemCount =>
      catalog.liveStreams.length +
      catalog.movies.length +
      catalog.series.length;

  @override
  String toString() => 'XtreamAddedProfile(profileId: $profileId)';
}

abstract interface class XtreamConnectionService {
  Future<XtreamAccountInfo> testConnection(XtreamConnectionInput input);

  Future<XtreamAddedProfile> addPlaylist(XtreamConnectionInput input);

  Future<Uri> resolveStreamUri(String profileId, XtreamMediaItem item);
}

abstract interface class XtreamProgressConnectionService {
  Future<XtreamAddedProfile> addPlaylistWithProgress(
    XtreamConnectionInput input, {
    XtreamCatalogProgress? onProgress,
    void Function()? onSaving,
    Duration? catalogTimeout,
    bool allowPartialCatalog,
  });
}

abstract interface class XtreamSourceRefreshService {
  Future<XtreamRefreshResult> refreshSource(String sourceId);
}

abstract interface class XtreamProgressRefreshService {
  Future<XtreamRefreshResult> refreshSourceWithProgress(
    String sourceId, {
    XtreamCatalogProgress? onProgress,
  });
}

abstract interface class XtreamCatalogPreviewService {
  Future<XtreamCatalog> previewCatalog(XtreamConnectionInput input);
}

abstract interface class XtreamSeriesService {
  Future<XtreamSeriesDetails> loadSeriesDetails(
    String profileId,
    String seriesId,
  );

  Future<Uri> resolveEpisodeStreamUri(String profileId, XtreamEpisode episode);
}

final class XtreamRefreshResult {
  const XtreamRefreshResult({
    required this.addedCount,
    required this.changedCount,
    required this.removedCount,
    required this.unchangedCount,
  });

  final int addedCount;
  final int changedCount;
  final int removedCount;
  final int unchangedCount;

  @override
  String toString() =>
      'XtreamRefreshResult(added: $addedCount, changed: $changedCount, '
      'removed: $removedCount, unchanged: $unchangedCount)';
}

final class DefaultXtreamConnectionService
    implements
        XtreamConnectionService,
        XtreamProgressConnectionService,
        XtreamCatalogPreviewService,
        XtreamSourceRefreshService,
        XtreamProgressRefreshService,
        XtreamSeriesService {
  DefaultXtreamConnectionService({
    http.Client? httpClient,
    SecureXtreamProfileStore? secretStore,
    Random? random,
    Future<ProfileSourceRepository> Function()? repositoryLoader,
    SourceIdentityService? identityService,
    this.catalogTimeout = const Duration(seconds: 90),
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _secretStore = secretStore ?? SecureXtreamProfileStore(),
       _random = random ?? Random.secure(),
       // ignore: prefer_initializing_formals
       _repositoryLoader = repositoryLoader,
       // ignore: prefer_initializing_formals
       _identityService = identityService;

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final SecureXtreamProfileStore _secretStore;
  final Random _random;
  final Future<ProfileSourceRepository> Function()? _repositoryLoader;
  final SourceIdentityService? _identityService;
  final Duration catalogTimeout;
  Future<void> _registrationTail = Future.value();

  @override
  Future<XtreamAccountInfo> testConnection(XtreamConnectionInput input) {
    return XtreamClient(_httpClient)
        .authenticate(_profile(input, 'connection-test'), input.credentials);
  }

  @override
  Future<XtreamCatalog> previewCatalog(XtreamConnectionInput input) async {
    final profile = _profile(input, 'catalog-preview');
    final client = XtreamClient(_httpClient, catalogTimeout: catalogTimeout);
    await client.authenticate(profile, input.credentials);
    return client.loadCatalog(profile, input.credentials);
  }

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final previous = _registrationTail;
    final completion = Completer<void>();
    _registrationTail = completion.future;
    await previous;
    try {
      return await operation();
    } finally {
      completion.complete();
    }
  }

  @override
  Future<XtreamAddedProfile> addPlaylist(XtreamConnectionInput input) =>
      addPlaylistWithProgress(input, allowPartialCatalog: false);

  @override
  Future<XtreamAddedProfile> addPlaylistWithProgress(
    XtreamConnectionInput input, {
    XtreamCatalogProgress? onProgress,
    void Function()? onSaving,
    Duration? catalogTimeout,
    bool allowPartialCatalog = false,
  }) => _serialized(
    () => _register(
      input,
      onProgress: onProgress,
      onSaving: onSaving,
      catalogTimeout: catalogTimeout ?? this.catalogTimeout,
      allowPartialCatalog: allowPartialCatalog,
    ),
  );

  @override
  Future<XtreamRefreshResult> refreshSource(String sourceId) =>
      refreshSourceWithProgress(sourceId);

  @override
  Future<XtreamRefreshResult> refreshSourceWithProgress(
    String sourceId, {
    XtreamCatalogProgress? onProgress,
  }) => _serialized(() => _refreshSource(sourceId, onProgress: onProgress));

  Future<XtreamRefreshResult> _refreshSource(
    String sourceId, {
    XtreamCatalogProgress? onProgress,
  }) async {
    final repository = await _repositoryLoader?.call();
    if (repository == null) throw const XtreamSecretStoreException();
    final active = await repository.activeProfile();
    final sources = await repository.sourcesForProfile(active.id);
    final source = sources
        .where((candidate) => candidate.id == sourceId)
        .firstOrNull;
    if (source == null) throw const XtreamSecretStoreException();
    final secret = await _secretStore.read(source.secretReference);
    if (secret == null) throw const XtreamSecretStoreException();
    final profile = XtreamProfile(
      id: source.id,
      displayName: source.displayName,
      serverUri: secret.serverUri,
      credentialReference: source.secretReference,
    );
    final client = XtreamClient(_httpClient, catalogTimeout: catalogTimeout);
    await client.authenticate(profile, secret.credentials);
    final catalog = await client.loadCatalog(
      profile,
      secret.credentials,
      onProgress: onProgress,
    );
    final incoming = _project(source.id, catalog);
    final previous = await repository.entriesForPlaylist(source.id);
    final diff = PlaylistDiff.calculate(previous: previous, incoming: incoming);
    await repository.registerSource(source, active.id, incoming);
    await _saveArtwork(source.id, catalog);
    return XtreamRefreshResult(
      addedCount: diff.added.length,
      changedCount: diff.changed.length,
      removedCount: diff.removed.length,
      unchangedCount: diff.unchanged.length,
    );
  }

  Future<XtreamAddedProfile> _register(
    XtreamConnectionInput input, {
    XtreamCatalogProgress? onProgress,
    void Function()? onSaving,
    required Duration catalogTimeout,
    required bool allowPartialCatalog,
  }) async {
    final repository = await _repositoryLoader?.call();
    final digest = await _identityService?.xtreamDigest(
      input.serverUri,
      input.credentials.username,
    );
    final existing = digest == null
        ? null
        : await repository?.sourceByIdentity(digest);
    final reference = existing?.secretReference ?? _secureReference();
    final profile = _profile(input, reference);
    final client = XtreamClient(_httpClient, catalogTimeout: catalogTimeout);
    final account = await client.authenticate(profile, input.credentials);
    final catalog = await client.loadCatalog(
      profile,
      input.credentials,
      onProgress: onProgress,
      allowPartialCatalog: allowPartialCatalog,
    );
    onSaving?.call();
    final active = await repository?.ensureDefaultProfile();
    final linked = active == null
        ? <IptvSource>[]
        : await repository!.sourcesForProfile(active.id);
    final previousSecret = existing == null
        ? null
        : await _secretStore.read(reference);
    await _secretStore.write(
      reference,
      XtreamConnectionSecret(
        serverUri: input.serverUri,
        credentials: input.credentials,
      ),
    );
    try {
      if (repository != null && active != null && digest != null) {
        await repository.registerSource(
          IptvSource(
            id: reference,
            displayName: input.profileName,
            identityDigest: digest,
            secretReference: reference,
          ),
          active.id,
          _project(reference, catalog),
        );
        await _saveArtwork(reference, catalog);
      }
    } catch (_) {
      if (previousSecret == null) {
        await _secretStore.delete(reference);
      } else {
        await _secretStore.write(reference, previousSecret);
      }
      throw const XtreamSecretStoreException();
    }
    return XtreamAddedProfile(
      profileId: reference,
      account: account,
      catalog: catalog,
      targetProfileId: active?.id,
      wasExisting: existing != null,
      wasAlreadyLinked: linked.any((source) => source.id == reference),
    );
  }

  List<PersistedMediaEntry> _project(String sourceId, XtreamCatalog catalog) {
    final categories = {
      for (final c in [
        ...catalog.liveCategories,
        ...catalog.movieCategories,
        ...catalog.seriesCategories,
      ])
        c.id: c.name,
    };
    return [
      for (final item in [...catalog.liveStreams, ...catalog.movies])
        PersistedMediaEntry(
          id: '${item.kind.name}:${item.id}',
          playlistId: sourceId,
          sourceReference: sourceId,
          originalName: item.name,
          displayName: item.name,
          groupName: categories[item.categoryId],
          kind: item.kind,
          externalId: item.id,
          containerExtension: item.containerExtension,
          epgChannelId: item.epgChannelId,
        ),
      for (final item in catalog.series)
        PersistedMediaEntry(
          id: 'series:${item.id}',
          playlistId: sourceId,
          sourceReference: sourceId,
          originalName: item.name,
          displayName: item.name,
          groupName: categories[item.categoryId],
          kind: MediaKind.episode,
          externalId: item.id,
        ),
    ];
  }

  Future<void> _saveArtwork(String sourceId, XtreamCatalog catalog) async {
    try {
      await ArtworkReferenceStore().write(sourceId, {
        for (final item in [...catalog.liveStreams, ...catalog.movies])
          if (item.imageUri case final Uri uri)
            '${item.kind.name}:${item.id}': uri,
        for (final item in catalog.series)
          if (item.coverUri case final Uri uri) 'series:${item.id}': uri,
      });
    } on Object {
      // Artwork storage must not discard a successfully imported catalog.
    }
  }

  @override
  Future<Uri> resolveStreamUri(String profileId, XtreamMediaItem item) async {
    final secret = await _requiredSecret(profileId);
    return XtreamStreamUriBuilder.build(
      profile: _storedProfile(profileId, secret),
      credentials: secret.credentials,
      item: item,
    );
  }

  @override
  Future<XtreamSeriesDetails> loadSeriesDetails(
    String profileId,
    String seriesId,
  ) async {
    final secret = await _requiredSecret(profileId);
    return XtreamClient(_httpClient).loadSeriesDetails(
      _storedProfile(profileId, secret),
      secret.credentials,
      seriesId: seriesId,
    );
  }

  @override
  Future<Uri> resolveEpisodeStreamUri(
    String profileId,
    XtreamEpisode episode,
  ) async {
    final secret = await _requiredSecret(profileId);
    return XtreamStreamUriBuilder.buildEpisode(
      profile: _storedProfile(profileId, secret),
      credentials: secret.credentials,
      episode: episode,
    );
  }

  Future<XtreamConnectionSecret> _requiredSecret(String profileId) async {
    final secret = await _secretStore.read(profileId);
    if (secret == null) throw const XtreamSecretStoreException();
    return secret;
  }

  XtreamProfile _storedProfile(
    String profileId,
    XtreamConnectionSecret secret,
  ) => XtreamProfile(
    id: profileId,
    displayName: 'Tvium',
    serverUri: secret.serverUri,
    credentialReference: profileId,
  );

  XtreamProfile _profile(XtreamConnectionInput input, String reference) {
    return XtreamProfile(
      id: reference,
      displayName: input.profileName,
      serverUri: input.serverUri,
      credentialReference: reference,
    );
  }

  String _secureReference() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  @override
  String toString() => 'DefaultXtreamConnectionService(***)';
}
