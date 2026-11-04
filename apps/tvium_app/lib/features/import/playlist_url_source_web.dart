import 'package:tvium_m3u/tvium_m3u.dart';

import 'web_provider_relay_client.dart';

M3uSource createPlaylistUrlSource(Uri uri) => _WebPlaylistUrlSource(uri);

final class _WebPlaylistUrlSource implements M3uSource {
  _WebPlaylistUrlSource(this.uri);

  final Uri uri;

  @override
  Stream<String> readLines() async* {
    final client = createProviderHttpClient();
    try {
      yield* M3uUrlSource(
        uri,
        client: client,
        timeout: const Duration(seconds: 120),
      ).readLines();
    } finally {
      client.close();
    }
  }
}
