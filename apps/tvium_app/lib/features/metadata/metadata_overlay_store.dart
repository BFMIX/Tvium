import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_core/tvium_core.dart';

import '../xtream/secure_xtream_profile_store.dart';
import 'metadata_gateway_client.dart';

final metadataOverlayStoreProvider = Provider<MetadataOverlayStore>(
  (ref) => MetadataOverlayStore(),
);

final metadataConsentStoreProvider = Provider<MetadataConsentStore>(
  (ref) => MetadataConsentStore(),
);

final class MetadataConsentStore {
  MetadataConsentStore([SecureKeyValueStore? backend])
    : _backend = backend ?? FlutterSecureKeyValueStore();

  static const _key = 'tvium.metadata.opt_in.v1';
  final SecureKeyValueStore _backend;

  Future<bool> read() async => await _backend.read(_key) == 'true';

  Future<void> write(bool enabled) =>
      _backend.write(_key, enabled ? 'true' : 'false');
}

typedef MetadataHeroRequest = ({
  String sourceId,
  String entryId,
  String title,
  MediaKind kind,
  bool enabled,
});

typedef MetadataCachedRequest = ({
  String sourceId,
  String entryId,
  String title,
  MediaKind kind,
  bool enabled,
});

final metadataCachedOverlayProvider =
    FutureProvider.family<MetadataOverlay?, MetadataCachedRequest>((
      ref,
      request,
    ) async {
      if (!request.enabled) return null;
      try {
        return await ref
            .read(metadataOverlayStoreProvider)
            .read(
              sourceId: request.sourceId,
              entryId: request.entryId,
              originalTitle: request.title,
              kind: request.kind,
            );
      } on Object {
        return null;
      }
    });

final metadataHeroOverlayProvider =
    FutureProvider.family<MetadataOverlay?, MetadataHeroRequest>((
      ref,
      request,
    ) async {
      if (!request.enabled) return null;
      final store = ref.read(metadataOverlayStoreProvider);
      try {
        final cached = await store.read(
          sourceId: request.sourceId,
          entryId: request.entryId,
          originalTitle: request.title,
          kind: request.kind,
        );
        if (cached != null) return cached;
        final client = ref.read(metadataGatewayProvider);
        if (client == null) return null;
        final query = const PlaylistTitleNormalizer().normalize(
          request.title,
          kind: request.kind,
        );
        final rows = await client.search(query);
        final match = const MetadataMatcher().match(
          query,
          rows.map((row) => row.candidate),
        );
        final candidate = match.candidate;
        if (match.status != MetadataMatchStatus.matched ||
            candidate == null ||
            candidate.provider != 'tmdb') {
          return null;
        }
        final row = rows
            .where(
              (row) =>
                  row.candidate.provider == candidate.provider &&
                  row.candidate.id == candidate.id,
            )
            .firstOrNull;
        if (row == null) return null;
        final overlay = MetadataOverlay(
          provider: candidate.provider,
          providerId: candidate.id,
          title: candidate.title,
          overview: row.overview,
          posterUri: row.posterUri,
          backdropUri: row.backdropUri,
          verified: true,
        );
        await store.write(
          sourceId: request.sourceId,
          entryId: request.entryId,
          originalTitle: request.title,
          kind: request.kind,
          overlay: overlay,
        );
        return overlay;
      } on Object {
        return null;
      }
    });

/// Enriches a grid card only if it remains mounted after a short scroll pause.
/// Cached verified artwork is returned immediately for restored libraries.
final metadataVisibleOverlayProvider = FutureProvider.autoDispose
    .family<MetadataOverlay?, MetadataHeroRequest>((ref, request) async {
      if (!request.enabled) return null;
      try {
        final cached = await ref
            .read(metadataOverlayStoreProvider)
            .read(
              sourceId: request.sourceId,
              entryId: request.entryId,
              originalTitle: request.title,
              kind: request.kind,
            );
        if (cached != null) return cached;
      } on Object {
        // A cache read failure may still leave the online lookup available.
      }
      var disposed = false;
      ref.onDispose(() => disposed = true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (disposed) return null;
      return ref.read(metadataHeroOverlayProvider(request).future);
    });

final class MetadataOverlay {
  const MetadataOverlay({
    required this.provider,
    required this.providerId,
    required this.title,
    required this.verified,
    this.overview,
    this.posterUri,
    this.backdropUri,
  });

  final String provider;
  final String providerId;
  final String title;
  final String? overview;
  final Uri? posterUri;
  final Uri? backdropUri;
  final bool verified;
}

/// A separate cache for verified public metadata. Source catalog rows remain
/// unchanged, and opaque storage keys do not contain playlist titles or IDs.
final class MetadataOverlayStore {
  MetadataOverlayStore([SecureKeyValueStore? backend])
    : _backend = backend ?? FlutterSecureKeyValueStore();

  final SecureKeyValueStore _backend;

  String _key(String sourceId, String entryId, String title, MediaKind kind) {
    final digest = sha256.convert(
      utf8.encode('$sourceId\u0000$entryId\u0000${kind.name}\u0000$title'),
    );
    return 'tvium.metadata.v1.$digest';
  }

  Future<void> write({
    required String sourceId,
    required String entryId,
    required String originalTitle,
    required MediaKind kind,
    required MetadataOverlay overlay,
  }) async {
    if (!overlay.verified ||
        overlay.provider != 'tmdb' ||
        !_publicImage(overlay.posterUri) ||
        !_publicImage(overlay.backdropUri)) {
      return;
    }
    await _backend.write(
      _key(sourceId, entryId, originalTitle, kind),
      jsonEncode({
        'provider': overlay.provider,
        'providerId': overlay.providerId,
        'title': overlay.title,
        'overview': overlay.overview,
        'poster': overlay.posterUri?.toString(),
        'backdrop': overlay.backdropUri?.toString(),
        'savedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
      }),
    );
  }

  Future<MetadataOverlay?> read({
    required String sourceId,
    required String entryId,
    required String originalTitle,
    required MediaKind kind,
  }) async {
    final raw = await _backend.read(
      _key(sourceId, entryId, originalTitle, kind),
    );
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          data['provider'] != 'tmdb' ||
          data['providerId'] is! String ||
          data['title'] is! String ||
          data['savedAt'] is! int) {
        return null;
      }
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
        data['savedAt'] as int,
        isUtc: true,
      );
      final age = DateTime.now().toUtc().difference(savedAt);
      if (age.isNegative || age > const Duration(days: 30)) return null;
      final poster = Uri.tryParse(data['poster'] as String? ?? '');
      final backdrop = Uri.tryParse(data['backdrop'] as String? ?? '');
      if (!_publicImage(poster) || !_publicImage(backdrop)) return null;
      return MetadataOverlay(
        provider: 'tmdb',
        providerId: data['providerId'] as String,
        title: data['title'] as String,
        overview: data['overview'] is String
            ? data['overview'] as String
            : null,
        posterUri: poster?.hasScheme == true ? poster : null,
        backdropUri: backdrop?.hasScheme == true ? backdrop : null,
        verified: true,
      );
    } on Object {
      return null;
    }
  }

  bool _publicImage(Uri? uri) =>
      uri == null ||
      uri.toString().isEmpty ||
      (uri.scheme == 'https' &&
          uri.host == 'image.tmdb.org' &&
          uri.userInfo.isEmpty &&
          !uri.hasQuery &&
          !uri.hasFragment);
}
