import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tvium_core/tvium_core.dart';

import 'xtream_account_info.dart';
import 'xtream_catalog.dart';
import 'xtream_credentials.dart';
import 'xtream_failure.dart';
import 'xtream_profile.dart';

final class XtreamClient {
  XtreamClient(this._httpClient, {this.timeout = const Duration(seconds: 15)});

  final http.Client _httpClient;
  final Duration timeout;

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
    XtreamCredentials credentials,
  ) async {
    final warnings = <String>[];
    final responses = <String, List<Object?>>{};
    for (final action in const <String>[
      'get_live_categories',
      'get_live_streams',
      'get_vod_categories',
      'get_vod_streams',
      'get_series_categories',
      'get_series',
    ]) {
      responses[action] = await _loadList(profile, credentials, action);
    }

    return XtreamCatalog(
      liveCategories: _mapRecords(
        responses['get_live_categories']!,
        _category,
        'live category',
        warnings,
      ),
      liveStreams: _mapRecords(
        responses['get_live_streams']!,
        (record) => _mediaItem(record, MediaKind.live),
        'live stream',
        warnings,
      ),
      movieCategories: _mapRecords(
        responses['get_vod_categories']!,
        _category,
        'movie category',
        warnings,
      ),
      movies: _mapRecords(
        responses['get_vod_streams']!,
        (record) => _mediaItem(record, MediaKind.movie),
        'movie',
        warnings,
      ),
      seriesCategories: _mapRecords(
        responses['get_series_categories']!,
        _category,
        'series category',
        warnings,
      ),
      series: _mapRecords(
        responses['get_series']!,
        _series,
        'series',
        warnings,
      ),
      warnings: warnings,
    );
  }

  Future<List<Object?>> _loadList(
    XtreamProfile profile,
    XtreamCredentials credentials,
    String action,
  ) async {
    final response = await _get(
      _endpoint(profile, credentials, action: action),
    );
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List<Object?>) {
        return decoded;
      }
    } on FormatException {
      // The typed failure below intentionally excludes response content.
    }
    throw const XtreamException(XtreamFailure.invalidResponse);
  }

  Future<http.Response> _get(Uri endpoint) async {
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
    return response;
  }

  Uri _endpoint(
    XtreamProfile profile,
    XtreamCredentials credentials, {
    String? action,
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
      },
      fragment: '',
    );
  }
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
