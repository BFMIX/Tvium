import 'package:test/test.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
  final profile = XtreamProfile(
    id: 'profile-1',
    displayName: 'Fixture',
    serverUri: Uri.parse('https://provider.example.test/base'),
    credentialReference: 'secret-1',
  );
  const credentials = XtreamCredentials(
    username: 'fixture user',
    password: 'fixture/password',
  );

  test('builds an encoded live stream URI', () {
    final uri = XtreamStreamUriBuilder.build(
      profile: profile,
      credentials: credentials,
      item: const XtreamMediaItem(
        id: '42',
        name: 'News',
        categoryId: null,
        kind: MediaKind.live,
        imageUri: null,
        containerExtension: null,
        epgChannelId: null,
      ),
    );

    expect(
      uri.toString(),
      'https://provider.example.test/base/live/fixture%20user/'
      'fixture%2Fpassword/42.ts',
    );
  });

  test('sanitizes an unsafe movie extension', () {
    final uri = XtreamStreamUriBuilder.build(
      profile: profile,
      credentials: credentials,
      item: const XtreamMediaItem(
        id: '84',
        name: 'Movie',
        categoryId: null,
        kind: MediaKind.movie,
        imageUri: null,
        containerExtension: '../mkv',
        epgChannelId: null,
      ),
    );

    expect(uri.pathSegments.last, '84.mp4');
  });
}
