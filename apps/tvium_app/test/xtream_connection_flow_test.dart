import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/xtream/xtream_connection_service.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
  testWidgets('tests and securely adds an Xtream profile', (tester) async {
    final service = _FakeXtreamConnectionService();
    await tester.pumpWidget(TviumApp(xtreamConnectionService: service));

    await tester.tap(find.byKey(const ValueKey<String>('xtream-action')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('xtream-profile-name')),
      'Home',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('xtream-server-url')),
      'https://provider.example.test:8443',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('xtream-username')),
      'fixture-user',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('xtream-password')),
      'fixture-password',
    );

    final testButton = find.byKey(
      const ValueKey<String>('xtream-test-connection'),
    );
    await tester.ensureVisible(testButton);
    await tester.tap(testButton);
    await tester.pumpAndSettle();

    expect(service.tested?.profileName, 'Home');
    expect(service.tested?.serverUri.host, 'provider.example.test');
    expect(service.tested?.credentials.username, 'fixture-user');
    expect(find.text('Connection successful'), findsOneWidget);

    final addButton = find.byKey(const ValueKey<String>('xtream-add-playlist'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(service.added?.credentials.password, 'fixture-password');
    expect(find.text('Playlist added: 3 items'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('xtream-password')),
          )
          .controller!
          .text,
      isEmpty,
    );
  });
}

final class _FakeXtreamConnectionService implements XtreamConnectionService {
  XtreamConnectionInput? tested;
  XtreamConnectionInput? added;

  @override
  Future<XtreamAccountInfo> testConnection(XtreamConnectionInput input) async {
    tested = input;
    return _account;
  }

  @override
  Future<XtreamAddedProfile> addPlaylist(XtreamConnectionInput input) async {
    added = input;
    return XtreamAddedProfile(
      profileId: 'profile-1',
      account: _account,
      catalog: XtreamCatalog(
        liveCategories: const <XtreamCategory>[],
        liveStreams: const <XtreamMediaItem>[
          XtreamMediaItem(
            id: '1',
            name: 'News',
            categoryId: null,
            kind: MediaKind.live,
            imageUri: null,
            containerExtension: null,
            epgChannelId: null,
          ),
        ],
        movieCategories: const <XtreamCategory>[],
        movies: const <XtreamMediaItem>[
          XtreamMediaItem(
            id: '2',
            name: 'Movie',
            categoryId: null,
            kind: MediaKind.movie,
            imageUri: null,
            containerExtension: 'mp4',
            epgChannelId: null,
          ),
        ],
        seriesCategories: const <XtreamCategory>[],
        series: const <XtreamSeriesSummary>[
          XtreamSeriesSummary(
            id: '3',
            name: 'Series',
            categoryId: null,
            coverUri: null,
          ),
        ],
        warnings: const <String>[],
      ),
    );
  }
}

const _account = XtreamAccountInfo(
  status: XtreamAccountStatus.active,
  isTrial: false,
  activeConnections: 0,
  maximumConnections: 1,
  expiresAt: null,
  timezone: null,
);
