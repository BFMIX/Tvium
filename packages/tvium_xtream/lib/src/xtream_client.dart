import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tvium_core/tvium_core.dart';

import 'xtream_account_info.dart';
import 'xtream_catalog.dart';
import 'xtream_catalog_step.dart';
import 'xtream_credentials.dart';
import 'xtream_failure.dart';
import 'xtream_json_decoder.dart';
import 'xtream_profile.dart';
import 'xtream_series_details.dart';

final class XtreamClient {
  XtreamClient(
    this._httpClient, {
    this.timeout = const Duration(seconds: 25),
    this.catalogTimeout = const Duration(seconds: 120),
  });

  final http.Client _httpClient;
  final Duration timeout;
  final Duration catalogTimeout;

  Future<XtreamAccountInfo> authenticate(
    XtreamProfile profile,
    XtreamCredentials credentials,
  ) async {
    final endpoint = _endpoint(profile, credentials);
    late http.Response response;
    try {
      response = await _httpClient.get(endpoint).timeout(timeout);
    } on TimeoutException {
      throw const XtreamException(XtreamFailure.networkTimeout);
    } on Object {
      throw const XtreamException(XtreamFailure.serverUnreachable);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const XtreamException(XtreamFailure.incorrectCredentials);
    }
    if (response.statusCode != 200) {
      throw const XtreamException(XtreamFailure.unavailable);
    }

    final payload = _decodeObject(response.body);
    final userInfo = _object(payload['user_info']);
    if (!_boolean(userInfo['auth'])) {
      throw const XtreamException(XtreamFailure.incorrectCredentials);
    }
    final serverInfo = _objectOrEmpty(payload['server_info']);

    return XtreamAccountInfo(
      status: _status(userInfo['status']),
      isTrial: _boolean(userInfo['is_trial']),
      activeConnections: _integer(userInfo['active_cons']),
      maximumConnections: _integer(userInfo['max_connections']),
      expiresAt: _dateTimeFromSeconds(userInfo['exp_date']),
      timezone: _nonEmptyString(serverInfo['timezone']),
    );
  }

  Future<XtreamCatalog> loadCatalog(
    XtreamProfile profile,
    XtreamCredentials credentials, {
    XtreamCatalogProgress? onProgress,
    bool allowPartialCatalog = false,
  }) async {
    final warnings = <String>[];
    var liveCategories = <XtreamCategory>[];
    var liveStreams = <XtreamMediaItem>[];
    var movieCategories = <XtreamCategory>[];
    var movies = <XtreamMediaItem>[];
    var seriesCategories = <XtreamCategory>[];
    var series = <XtreamSeriesSummary>[];
    for (final step in XtreamCatalogStep.values) {
      onProgress?.call(step, step.index + 1, XtreamCatalogStep.values.length);
      late final List<Object?> records;
      try {
        records = await _loadList(profile, credentials, step);
      } on XtreamException catch (error) {
        if (!allowPartialCatalog ||
            error.failure != XtreamFailure.networkTimeout ||
            step.index < XtreamCatalogStep.vodCategories.index ||
            liveStreams.isEmpty) {
          rethrow;
        }
        records = const <Object?>[];
        warnings.add('The ${step.name} catalog timed out and was skipped.');
      }
      switch (step) {
        case XtreamCatalogStep.liveCategories:
          liveCategories = _mapRecords(
            records,
            _category,
            'live category',
            warnings,
          );
        case XtreamCatalogStep.liveStreams:
          liveStreams = _mapRecords(
            records,
            (record) => _mediaItem(record, MediaKind.live),
            'live stream',
            warnings,
          );
        case XtreamCatalogStep.vodCategories:
          movieCategories = _mapRecords(
            records,
            _category,
            'movie category',
            warnings,
          );
        case XtreamCatalogStep.vodStreams:
          movies = _mapRecords(
            records,
            (record) => _mediaItem(record, MediaKind.movie),
            'movie',
            warnings,
          );
        case XtreamCatalogStep.seriesCategories:
          seriesCategories = _mapRecords(
            records,
            _category,
            'series category',
            warnings,
          );
        case XtreamCatalogStep.series:
          series = _mapRecords(records, _series, 'series', warnings);
      }
    }

    return XtreamCatalog(
      liveCategories: liveCategories,
      liveStreams: liveStreams,
      movieCategories: movieCategories,
      movies: movies,
      seriesCategories: seriesCategories,
      series: series,
      warnings: warnings,
    );
  }

  Future<XtreamSeriesDetails> loadSeriesDetails(
    XtreamProfile profile,
    XtreamCredentials credentials, {
    required String seriesId,
  }) async {
    final response = await _get(
      _endpoint(
        profile,
        credentials,
        action: 'get_series_info',
        extraQueryParameters: <String, String>{'series_id': seriesId},
      ),
    );
    final payload = _decodeObject(response.body);
    final info = _object(payload['info']);
    final warnings = <String>[];
    final seasonMetadata = <int, _SeasonMetadata>{};

    final rawSeasons = payload['seasons'];
    if (rawSeasons != null) {
      if (rawSeasons is! List<Object?>) {
        throw const XtreamException(XtreamFailure.invalidResponse);
      }
      for (final value in rawSeasons) {
        try {
          final metadata = _seasonMetadata(_object(value));
          seasonMetadata[metadata.number] = metadata;
        } on XtreamException {
          warnings.add('Skipped malformed season record.');
        }
      }
    }

    final episodesBySeason = <int, List<XtreamEpisode>>{};
    final rawEpisodes = payload['episodes'];
    if (rawEpisodes != null) {
      final episodes = _object(rawEpisodes);
      for (final entry in episodes.entries) {
        final bucketSeason = int.tryParse(entry.key);
        final values = entry.value;
        if (bucketSeason == null || bucketSeason <= 0 || values is! List) {
          warnings.add('Skipped malformed season episode list.');
          continue;
        }
        for (final value in values) {
          try {
            final episode = _episode(_object(value), bucketSeason);
            episodesBySeason
                .putIfAbsent(episode.seasonNumber, () => <XtreamEpisode>[])
                .add(episode);
          } on XtreamException {
            warnings.add('Skipped malformed episode record.');
          }
        }
      }
    }

    final seasonNumbers = <int>{
      ...seasonMetadata.keys,
      ...episodesBySeason.keys,
    }.toList()..sort();
    final seasons = <XtreamSeason>[];
    for (final number in seasonNumbers) {
      final metadata = seasonMetadata[number];
      final episodes = episodesBySeason[number] ?? <XtreamEpisode>[];
      episodes.sort((left, right) => left.number.compareTo(right.number));
      seasons.add(
        XtreamSeason(
          id: metadata?.id,
          number: number,
          name: metadata?.name ?? 'Season $number',
          overview: metadata?.overview,
          coverUri: metadata?.coverUri,
          episodes: episodes,
        ),
      );
    }

    return XtreamSeriesDetails(
      id: seriesId,
      name: _requiredText(info['name']),
      coverUri: _safeHttpUri(info['cover']),
      backdropUris: _uriList(info['backdrop_path']),
      plot: _nonEmptyString(info['plot']),
      cast: _nonEmptyString(info['cast']),
      director: _nonEmptyString(info['director']),
      genre: _nonEmptyString(info['genre']),
      releasedAt: _dateTime(info['releaseDate'] ?? info['release_date']),
      rating: _decimal(info['rating']),
      seasons: seasons,
      warnings: warnings,
    );
  }

  Future<List<Object?>> _loadList(
    XtreamProfile profile,
    XtreamCredentials credentials,
    XtreamCatalogStep step,
  ) async {
    final response = await _get(
      _endpoint(profile, credentials, action: step.action),
      requestTimeout: catalogTimeout,
      catalogStep: step,
    );
    try {
      final decoded = await decodeXtreamJson(response.bodyBytes);
      if (decoded is List<Object?>) {
        return decoded;
      }
    } on FormatException {
      // The typed failure below intentionally excludes response content.
    }
    throw const XtreamException(XtreamFailure.invalidResponse);
  }

  Future<http.Response> _get(
    Uri endpoint, {
    Duration? requestTimeout,
    XtreamCatalogStep? catalogStep,
  }) async {
    late http.Response response;
    try {
      response = await _httpClient
          .get(endpoint)
          .timeout(requestTimeout ?? timeout);
    } on TimeoutException {
      throw XtreamException(
        XtreamFailure.networkTimeout,
        catalogStep: catalogStep,
      );
    } on Object {
      throw const XtreamException(XtreamFailure.serverUnreachable);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const XtreamException(XtreamFailure.incorrectCredentials);
    }
    if (response.statusCode != 200) {
      throw const XtreamException(XtreamFailure.unavailable);
    }
    return response;
  }

  Uri _endpoint(
    XtreamProfile profile,
    XtreamCredentials credentials, {
    String? action,
    Map<String, String> extraQueryParameters = const <String, String>{},
  }) {
    final basePath = profile.serverUri.path.endsWith('/')
        ? profile.serverUri.path.substring(0, profile.serverUri.path.length - 1)
        : profile.serverUri.path;
    return profile.serverUri.replace(
      path: '$basePath/player_api.php',
      queryParameters: <String, String>{
        'username': credentials.username,
        'password': credentials.password,
        'action': ?action,
        ...extraQueryParameters,
      },
      fragment: '',
    );
  }
}

final class _SeasonMetadata {
  const _SeasonMetadata({
    required this.id,
    required this.number,
    required this.name,
    required this.overview,
    required this.coverUri,
  });

  final String? id;
  final int number;
  final String? name;
  final String? overview;
  final Uri? coverUri;
}

_SeasonMetadata _seasonMetadata(Map<String, Object?> record) {
  final number = _integer(record['season_number']);
  if (number == null || number <= 0) {
    throw const XtreamException(XtreamFailure.invalidResponse);
  }
  return _SeasonMetadata(
    id: _nonEmptyString(record['id']),
    number: number,
    name: _nonEmptyString(record['name']),
    overview: _nonEmptyString(record['overview']),
    coverUri: _safeHttpUri(record['cover'] ?? record['cover_big']),
  );
}

XtreamEpisode _episode(Map<String, Object?> record, int bucketSeason) {
  final seasonNumber = _integer(record['season']) ?? bucketSeason;
  final number = _integer(record['episode_num']);
  if (seasonNumber <= 0 || number == null || number <= 0) {
    throw const XtreamException(XtreamFailure.invalidResponse);
  }
  final info = _objectOrEmpty(record['info']);
  return XtreamEpisode(
    id: _requiredText(record['id']),
    seasonNumber: seasonNumber,
    number: number,
    title: _requiredText(record['title']),
    containerExtension: _nonEmptyString(record['container_extension']),
    imageUri: _safeHttpUri(info['movie_image'] ?? info['cover_big']),
    plot: _nonEmptyString(info['plot']),
    releasedAt: _dateTime(info['releasedate'] ?? info['release_date']),
    rating: _decimal(info['rating']),
    duration: _duration(info),
  );
}

List<T> _mapRecords<T>(
  List<Object?> records,
  T Function(Map<String, Object?> record) mapper,
  String label,
  List<String> warnings,
) {
  final mapped = <T>[];
  for (final value in records) {
    try {
      mapped.add(mapper(_object(value)));
    } on XtreamException {
      warnings.add('Skipped malformed $label record.');
    }
  }
  return mapped;
}

XtreamCategory _category(Map<String, Object?> record) {
  return XtreamCategory(
    id: _requiredText(record['category_id']),
    name: _requiredText(record['category_name']),
  );
}

XtreamMediaItem _mediaItem(Map<String, Object?> record, MediaKind kind) {
  return XtreamMediaItem(
    id: _requiredText(record['stream_id']),
    name: _requiredText(record['name']),
    categoryId: _nonEmptyString(record['category_id']),
    kind: kind,
    imageUri: _safeHttpUri(record['stream_icon']),
    containerExtension: _nonEmptyString(record['container_extension']),
    epgChannelId: _nonEmptyString(record['epg_channel_id']),
  );
}

XtreamSeriesSummary _series(Map<String, Object?> record) {
  return XtreamSeriesSummary(
    id: _requiredText(record['series_id']),
    name: _requiredText(record['name']),
    categoryId: _nonEmptyString(record['category_id']),
    coverUri: _safeHttpUri(record['cover']),
  );
}

String _requiredText(Object? value) {
  final text = _nonEmptyString(value);
  if (text == null) {
    throw const XtreamException(XtreamFailure.invalidResponse);
  }
  return text;
}

Uri? _safeHttpUri(Object? value) {
  final uri = Uri.tryParse(value?.toString() ?? '');
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}

Map<String, Object?> _decodeObject(String body) {
  try {
    return _object(jsonDecode(body));
  } on FormatException {
    throw const XtreamException(XtreamFailure.invalidResponse);
  }
}

Map<String, Object?> _object(Object? value) {
  if (value case final Map<Object?, Object?> map) {
    return map.map(
      (key, value) => MapEntry<String, Object?>(key.toString(), value),
    );
  }
  throw const XtreamException(XtreamFailure.invalidResponse);
}

Map<String, Object?> _objectOrEmpty(Object? value) {
  if (value == null) {
    return const <String, Object?>{};
  }
  return _object(value);
}

bool _boolean(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  return switch (value?.toString().trim().toLowerCase()) {
    '1' || 'true' || 'yes' => true,
    _ => false,
  };
}

int? _integer(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _decimal(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _dateTime(Object? value) {
  final parsed = DateTime.tryParse(value?.toString().trim() ?? '');
  if (parsed == null) {
    return null;
  }
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  );
}

Duration? _duration(Map<String, Object?> info) {
  final seconds = _integer(info['duration_secs']);
  if (seconds != null && seconds > 0) {
    return Duration(seconds: seconds);
  }
  final parts = info['duration']?.toString().split(':');
  if (parts == null || parts.length != 3) {
    return null;
  }
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  final remainingSeconds = int.tryParse(parts[2]);
  if (hours == null || minutes == null || remainingSeconds == null) {
    return null;
  }
  return Duration(hours: hours, minutes: minutes, seconds: remainingSeconds);
}

List<Uri> _uriList(Object? value) {
  if (value is! List<Object?>) {
    return const <Uri>[];
  }
  return <Uri>[
    for (final candidate in value)
      if (_safeHttpUri(candidate) case final Uri uri) uri,
  ];
}

DateTime? _dateTimeFromSeconds(Object? value) {
  final seconds = _integer(value);
  if (seconds == null || seconds <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

String? _nonEmptyString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

XtreamAccountStatus _status(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'active' => XtreamAccountStatus.active,
    'disabled' => XtreamAccountStatus.disabled,
    'expired' => XtreamAccountStatus.expired,
    'banned' => XtreamAccountStatus.banned,
    _ => XtreamAccountStatus.unknown,
  };
}
