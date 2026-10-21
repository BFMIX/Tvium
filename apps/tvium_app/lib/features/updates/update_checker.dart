import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

const installedReleaseTag = String.fromEnvironment('TVIUM_RELEASE_TAG');

final installedReleaseTagProvider = Provider<String>(
  (ref) => installedReleaseTag,
);

final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  final checker = UpdateChecker();
  ref.onDispose(checker.close);
  return checker;
});

final class AvailableUpdate {
  const AvailableUpdate(this.tag, this.page);

  final String tag;
  final Uri page;
}

final class UpdateCheckException implements Exception {
  const UpdateCheckException();

  @override
  String toString() => 'Could not check for updates. Try again later.';
}

/// Reads public release metadata only. It never sends library or account data.
final class UpdateChecker {
  UpdateChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final _releases = Uri.https(
    'api.github.com',
    '/repos/BFMIX/Tvium/releases',
    <String, String>{'per_page': '20'},
  );

  Future<AvailableUpdate?> check(String currentTag) async {
    final current = _version(currentTag);
    if (current == null) return null;
    try {
      final response = await _client
          .get(
            _releases,
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Tvium-update-check',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw const UpdateCheckException();
      final data = jsonDecode(response.body);
      if (data is! List) throw const UpdateCheckException();
      AvailableUpdate? newest;
      Version? newestVersion;
      for (final item in data) {
        if (item is! Map<String, dynamic> || item['draft'] != false) continue;
        final tag = item['tag_name'];
        final rawPage = item['html_url'];
        if (tag is! String || rawPage is! String) continue;
        final version = _version(tag);
        final page = Uri.tryParse(rawPage);
        if (version == null ||
            version <= current ||
            (!current.isPreRelease && item['prerelease'] == true) ||
            page == null ||
            page.scheme != 'https' ||
            page.host != 'github.com' ||
            page.path != '/BFMIX/Tvium/releases/tag/$tag') {
          continue;
        }
        if (newestVersion == null || version > newestVersion) {
          newest = AvailableUpdate(tag, page);
          newestVersion = version;
        }
      }
      return newest;
    } on Object {
      throw const UpdateCheckException();
    }
  }

  void close() => _client.close();
}

Version? _version(String tag) {
  final value = tag.startsWith('v') ? tag.substring(1) : tag;
  try {
    return Version.parse(value);
  } on FormatException {
    return null;
  }
}
