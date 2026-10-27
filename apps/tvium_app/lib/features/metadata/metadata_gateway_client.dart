import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tvium_core/tvium_core.dart';

final metadataGatewayProvider = Provider<MetadataGatewayClient?>((ref) {
  const address = String.fromEnvironment('TVIUM_METADATA_GATEWAY');
  final uri = resolveMetadataGatewayEndpoint(
    configuredAddress: address,
    platform: defaultTargetPlatform,
    isWeb: kIsWeb,
  );
  if (uri == null) return null;
  final client = MetadataGatewayClient(endpoint: uri);
  ref.onDispose(client.close);
  return client;
});

Uri? resolveMetadataGatewayEndpoint({
  required String configuredAddress,
  required TargetPlatform platform,
  required bool isWeb,
}) {
  final address = configuredAddress.isNotEmpty
      ? configuredAddress
      : 'https://tvium.netlify.app';
  final uri = Uri.tryParse(address);
  if (uri == null || !uri.hasAuthority || uri.userInfo.isNotEmpty) return null;
  if (uri.scheme == 'https') return uri;
  if (uri.scheme == 'http' &&
      const <String>['localhost', '127.0.0.1', '::1'].contains(uri.host)) {
    return uri;
  }
  return null;
}

final class EnrichedMetadata {
  const EnrichedMetadata({
    required this.candidate,
    this.overview,
    this.posterUri,
    this.backdropUri,
  });
  final MetadataCandidate candidate;
  final String? overview;
  final Uri? posterUri;
  final Uri? backdropUri;
}

final class MetadataLookupException implements Exception {
  const MetadataLookupException();
  @override
  String toString() => 'Metadata is unavailable. Your playlist is unchanged.';
}

/// Only derived public identity fields cross this boundary. No source objects.
final class MetadataGatewayClient {
  MetadataGatewayClient({required this.endpoint, http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final Uri endpoint;
  final http.Client _client;
  final bool _ownsClient;
  final _cache = <String, (DateTime, List<EnrichedMetadata>)>{};

  static bool safeTitle(String value) {
    if (value.isEmpty || value.length > 200 || value.trim() != value) {
      return false;
    }
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      return false;
    }
    if (RegExp(
      r'[A-Z][A-Z0-9+.-]{1,15}://|\bwww\.|(?:^|\s)(?:[A-Z0-9-]+\.)+[A-Z]{2,}(?::\d{1,5})?/',
      caseSensitive: false,
    ).hasMatch(value)) {
      return false;
    }
    if (RegExp(
      r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
      caseSensitive: false,
    ).hasMatch(value)) {
      return false;
    }
    if (RegExp(
      r'(?:^|[?&;\s])(?:username|user|password|pass|token|api[_-]?key)\s*[=:]',
      caseSensitive: false,
    ).hasMatch(value)) {
      return false;
    }
    return !RegExp(
      r'\bbearer\s+[A-Z0-9._~-]{8,}',
      caseSensitive: false,
    ).hasMatch(value);
  }

  Future<List<EnrichedMetadata>> search(NormalizedPlaylistTitle title) async {
    if (!safeTitle(title.title) ||
        (title.language != null &&
            !RegExp(r'^[a-z]{2}(?:-[A-Z]{2})?$').hasMatch(title.language!)) ||
        (title.year != null && (title.year! < 1888 || title.year! > 2100)) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        (endpoint.scheme != 'https' &&
            !(endpoint.scheme == 'http' &&
                const [
                  'localhost',
                  '127.0.0.1',
                  '::1',
                ].contains(endpoint.host)))) {
      throw const MetadataLookupException();
    }
    final kind = switch (title.kind) {
      MediaKind.movie => 'movie',
      MediaKind.episode => 'series',
      MediaKind.live => 'live',
      MediaKind.unclassified => null,
    };
    if (kind == null) {
      return const [];
    }
    final body = jsonEncode({
      'title': title.title,
      'kind': kind,
      if (title.year != null) 'year': title.year,
      'language': switch (title.language) {
        null || 'fr' => 'fr-FR',
        'en' => 'en-US',
        final language => language,
      },
    });
    final cached = _cache[body];
    if (cached != null && cached.$1.isAfter(DateTime.now())) {
      return cached.$2;
    }
    try {
      final request = http.Request('POST', endpoint.resolve('/v1/search'))
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..body = body;
      final result = await (() async {
        final response = await _client.send(request);
        if (response.statusCode != 200) {
          throw const MetadataLookupException();
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 512 * 1024) {
            throw const MetadataLookupException();
          }
          bytes.addAll(chunk);
        }
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final rows = json['candidates'] as List<dynamic>;
        if (rows.length > 50) {
          throw const MetadataLookupException();
        }
        final now = DateTime.now().toUtc();
        final parsed = <EnrichedMetadata>[];
        for (final row in rows) {
          if (row is! Map<String, dynamic>) {
            continue;
          }
          final id = row['id'];
          final provider = row['provider'];
          final name = row['title'];
          final license = row['license'];
          if (id is! String ||
              provider is! String ||
              name is! String ||
              license is! String ||
              !const [
                'tmdb',
                'tvmaze',
                'iptv-org',
                'wikidata',
              ].contains(provider) ||
              row['kind'] != kind ||
              name.trim().isEmpty ||
              name.length > 300 ||
              id.isEmpty ||
              id.length > 200 ||
              license.isEmpty ||
              license.length > 2000) {
            continue;
          }
          parsed.add(
            EnrichedMetadata(
              candidate: MetadataCandidate(
                provider: provider,
                id: id,
                title: name,
                alternativeTitles: [
                  if (row['originalTitle'] case final String originalTitle)
                    if (safeTitle(originalTitle)) originalTitle,
                  if (row['alternativeTitles'] case final List<dynamic> aliases)
                    ...aliases.whereType<String>().where(safeTitle).take(5),
                ],
                kind: title.kind,
                year: row['year'] is int ? row['year'] as int : null,
                provenance: MetadataProvenance(
                  provider: provider,
                  fetchedAt: now,
                  expiresAt: now.add(const Duration(hours: 24)),
                  attribution: license,
                  sourceUri: _publicUri(row['sourceUrl']),
                ),
              ),
              overview: row['overview'] is String
                  ? (row['overview'] as String).substring(
                      0,
                      (row['overview'] as String).length.clamp(0, 5000),
                    )
                  : null,
              posterUri: _publicUri(row['posterUrl']),
              backdropUri: _publicUri(row['backdropUrl']),
            ),
          );
        }
        return List<EnrichedMetadata>.unmodifiable(parsed);
      })().timeout(const Duration(seconds: 12));
      _cache[body] = (DateTime.now().add(const Duration(hours: 24)), result);
      if (_cache.length > 200) {
        _cache.remove(_cache.keys.first);
      }
      return result;
    } on Object {
      throw const MetadataLookupException();
    }
  }

  static Uri? _publicUri(Object? value) {
    if (value is! String) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    const hosts = [
      'www.themoviedb.org',
      'image.tmdb.org',
      'www.tvmaze.com',
      'static.tvmaze.com',
      'iptv-org.github.io',
      'www.wikidata.org',
    ];
    return hosts.contains(uri.host) ? uri : null;
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
