import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/xtream/xtream_connection_service.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

void main() {
  testWidgets('uses paged storage after a saved Xtream import', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = InMemoryProfileSourceRepository();
    final active = await repository.ensureDefaultProfile();
    final service = _SavedXtreamConnectionService(repository, active.id);
    await tester.pumpWidget(
      TviumApp(
        xtreamConnectionService: service,
        profileSourceRepository: repository,
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('xtream-action')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('xtream-profile-name')),
      'Fixture',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('xtream-server-url')),
      'https://provider.example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('xtream-username')),
      'fixture-user',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('xtream-password')),
      'fixture-password',
    );
    final addButton = find.byKey(const ValueKey<String>('xtream-add-playlist'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('catalog-pagination')), findsOneWidget);
    expect(find.text('1–120 / 260'), findsOneWidget);
  });

  testWidgets('tests and securely adds an Xtream profile', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FakeXtreamConnectionService();
    final repository = InMemoryProfileSourceRepository();
    await repository.ensureDefaultProfile();
    await repository.createProfile('Kids');
    await tester.pumpWidget(
      TviumApp(
        xtreamConnectionService: service,
        profileSourceRepository: repository,
      ),
    );

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

    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    expect(find.text('News'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Movies'));
    await tester.pumpAndSettle();
    expect(find.text('Movie'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'TV Shows'));
    await tester.pumpAndSettle();
    expect(find.text('Series'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('xtream-password')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Kids'));
    await tester.pumpAndSettle();

    expect(find.text('News'), findsNothing);
    expect(find.text('Welcome to Tvium'), findsOneWidget);
  });
}

final class _SavedXtreamConnectionService implements XtreamConnectionService {
  _SavedXtreamConnectionService(this.repository, this.profileId);
  final InMemoryProfileSourceRepository repository;
  final String profileId;

  @override
  Future<XtreamAccountInfo> testConnection(XtreamConnectionInput input) async =>
      _account;

  @override
  Future<XtreamAddedProfile> addPlaylist(XtreamConnectionInput input) async {
    const source = IptvSource(
      id: 'saved-xtream',
      displayName: 'Fixture',
      identityDigest: 'fixture-digest',
      secretReference: 'fixture-secret',
    );
    await repository.registerSource(source, profileId, [
      for (var index = 0; index < 260; index++)
        PersistedMediaEntry(
          id: 'movie:$index',
          playlistId: source.id,
          sourceReference: source.id,
          originalName: 'Fixture Movie $index',
          displayName: 'Fixture Movie $index',
          groupName: 'Fixture',
          kind: MediaKind.movie,
          externalId: '$index',
        ),
    ]);
    return XtreamAddedProfile(
      profileId: source.id,
      account: _account,
      targetProfileId: profileId,
      catalog: XtreamCatalog(
        liveCategories: const [],
        liveStreams: const [],
        movieCategories: const [],
        movies: [
          for (var index = 0; index < 260; index++)
            XtreamMediaItem(
              id: '$index',
              name: 'Fixture Movie $index',
              categoryId: null,
              kind: MediaKind.movie,
              imageUri: null,
              containerExtension: null,
              epgChannelId: null,
            ),
        ],
        seriesCategories: const [],
        series: const [],
        warnings: const [],
      ),
    );
  }

  @override
  Future<Uri> resolveStreamUri(String profileId, XtreamMediaItem item) async =>
      Uri.parse('https://stream.example.test/${item.id}');
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

  @override
  Future<Uri> resolveStreamUri(String profileId, XtreamMediaItem item) async =>
      Uri.parse('https://stream.example.test/${item.id}');
}

const _account = XtreamAccountInfo(
  status: XtreamAccountStatus.active,
  isTrial: false,
  activeConnections: 0,
  maximumConnections: 1,
  expiresAt: null,
  timezone: null,
);
