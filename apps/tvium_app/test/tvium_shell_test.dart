import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/import/playlist_import_controller.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_m3u/tvium_m3u.dart';
import 'package:tvium_playback/tvium_playback.dart';

void main() {
  testWidgets('home leads with exactly the three catalog destinations', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('destination-live')), findsOneWidget);
    expect(find.byKey(const ValueKey('destination-movies')), findsOneWidget);
    expect(find.byKey(const ValueKey('destination-shows')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-media-rail')), findsNothing);
    expect(find.text('Demo News'), findsNothing);
  });

  testWidgets('live destination shows channels without movie or show rows', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('page-live')), findsOneWidget);
    expect(find.text('Demo News'), findsOneWidget);
    expect(find.text('Demo Movie'), findsNothing);
    expect(find.text('Demo Show'), findsNothing);
    expect(find.text('Program guide unavailable'), findsOneWidget);
  });

  testWidgets('Live TV country rail filters only explicit country groups', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _CountryFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('live-country-rail')), findsOneWidget);
    expect(find.text('Fixture France'), findsOneWidget);
    expect(find.text('Fixture United States'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('country-US')));
    await tester.pumpAndSettle();
    expect(find.text('Fixture United States'), findsOneWidget);
    expect(find.text('Fixture France'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('country-all')));
    await tester.pumpAndSettle();
    expect(find.text('Fixture Region'), findsOneWidget);
  });

  testWidgets('wide Live TV places player beside the channel stack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: InMemoryProfileSourceRepository(),
        playbackEngineFactory: _FakePlaybackEngine.new,
        playbackViewBuilder: (_) => const SizedBox(),
      ),
    );
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-row-entry-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('catalog-player')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('catalog-player'))).dx,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('live-channel-list'))).dx,
      ),
    );
  });

  testWidgets('wide catalogs keep categories in a left navigation rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: InMemoryProfileSourceRepository(),
      ),
    );

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();

    final rail = find.byKey(const ValueKey('catalog-group-sidebar'));
    final channels = find.byKey(const ValueKey('live-channel-list'));
    expect(rail, findsOneWidget);
    expect(
      tester.getTopLeft(rail).dx,
      lessThan(tester.getTopLeft(channels).dx),
    );
  });

  testWidgets('poster catalogs use a width-responsive compact grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: InMemoryProfileSourceRepository(),
      ),
    );

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(
      find.byKey(const ValueKey('poster-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(delegate.maxCrossAxisExtent, lessThanOrEqualTo(220));
  });

  testWidgets('M3U episodes are grouped into one series with seasons', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: InMemoryProfileSourceRepository(),
      ),
    );

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-shows')));
    await tester.pumpAndSettle();

    expect(find.text('Demo Show'), findsOneWidget);
    await tester.tap(find.text('Demo Show'));
    await tester.pumpAndSettle();

    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('2 episodes'), findsOneWidget);
  });

  testWidgets('movie Play now opens a visible playback surface', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    final playback = _FakePlaybackEngine();
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: InMemoryProfileSourceRepository(),
        playbackEngineFactory: () => playback,
        playbackViewBuilder: (_) =>
            const SizedBox(key: ValueKey('test-playback-view')),
      ),
    );

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('media-card-movie')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-card-movie')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('title-details')), findsOneWidget);
    expect(find.text('Demo Movie'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Play now'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Play now'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('catalog-player')), findsOneWidget);
    expect(find.byKey(const ValueKey('test-playback-view')), findsOneWidget);
  });

  testWidgets('TV show Play now opens a visible playback surface', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    final playback = _FakePlaybackEngine();
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: InMemoryProfileSourceRepository(),
        playbackEngineFactory: () => playback,
        playbackViewBuilder: (_) =>
            const SizedBox(key: ValueKey('test-playback-view')),
      ),
    );

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-shows')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo Show'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Play now'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('catalog-player')), findsOneWidget);
    expect(find.byKey(const ValueKey('test-playback-view')), findsOneWidget);
  });

  testWidgets('movie playback resumes from saved progress', (tester) async {
    final repository = InMemoryProfileSourceRepository();
    final profile = await repository.ensureDefaultProfile();
    await repository.recordPlayback(
      PlaybackHistoryEntry(
        media: MediaLocator(
          profileId: profile.id,
          sourceId: 'session.m3u',
          entryId: 'entry-2',
        ),
        lastPlayedAtUtc: DateTime.utc(2026, 10, 19),
        position: const Duration(seconds: 42),
        duration: const Duration(minutes: 2),
      ),
    );
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    final playback = _FakePlaybackEngine();
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: repository,
        playbackEngineFactory: () => playback,
        playbackViewBuilder: (_) => const SizedBox(),
      ),
    );

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('media-card-movie')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-card-movie')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Play now'));
    await tester.pumpAndSettle();

    expect(playback.seekPositions, const <Duration>[Duration(seconds: 42)]);
  });

  testWidgets('movie playback checkpoints its real position', (tester) async {
    final repository = InMemoryProfileSourceRepository();
    final profile = await repository.ensureDefaultProfile();
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    final playback = _FakePlaybackEngine();
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: repository,
        playbackEngineFactory: () => playback,
        playbackViewBuilder: (_) => const SizedBox(),
      ),
    );

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-card-movie')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Play now'));
    await tester.pumpAndSettle();

    playback.emit(
      const PlaybackState(
        phase: PlaybackPhase.playing,
        position: Duration(seconds: 45),
        duration: Duration(minutes: 2),
      ),
    );
    await tester.pumpAndSettle();

    final history = await repository.historyForProfile(profile.id);
    expect(history.single.position, const Duration(seconds: 45));
    expect(history.single.duration, const Duration(minutes: 2));
  });

  testWidgets('Home shows only destinations followed by the carousel', (
    tester,
  ) async {
    final repository = InMemoryProfileSourceRepository();
    final profile = await repository.ensureDefaultProfile();
    await repository.recordPlayback(
      PlaybackHistoryEntry(
        media: MediaLocator(
          profileId: profile.id,
          sourceId: 'session.m3u',
          entryId: 'entry-2',
        ),
        lastPlayedAtUtc: DateTime.utc(2026, 10, 19),
        position: const Duration(seconds: 42),
        duration: const Duration(minutes: 2),
      ),
    );
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: repository,
      ),
    );

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('destination-live')), findsOneWidget);
    expect(find.byKey(const ValueKey('destination-movies')), findsOneWidget);
    expect(find.byKey(const ValueKey('destination-shows')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-hero')), findsOneWidget);
    expect(find.text('Continue watching'), findsNothing);
    expect(find.byKey(const ValueKey('recently-played')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('destination-live'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('home-hero'))).dy),
    );
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('movies-continue-watching')),
      findsOneWidget,
    );
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('continue-progress-entry-2')),
    );
    expect(progress.value, closeTo(0.35, 0.001));
  });

  testWidgets('Home presents a cinematic hero with timed controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-hero')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-hero-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-hero-details')), findsOneWidget);
    final initialTitle = tester.widget<Text>(
      find.byKey(const ValueKey('home-hero-title')).last,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 350));

    final nextTitle = tester.widget<Text>(
      find.byKey(const ValueKey('home-hero-title')),
    );
    expect(nextTitle.data, isNot(initialTitle.data));
  });

  testWidgets('Home uses fixed destination art and a spacious hero gap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    for (final (destination, asset) in [
      ('live', 'assets/destinations/hero-live-tv.png'),
      ('movies', 'assets/destinations/hero-movies.png'),
      ('shows', 'assets/destinations/hero-tv-shows.png'),
    ]) {
      final card = find.byKey(ValueKey('destination-$destination'));
      final images = tester.widgetList<Image>(
        find.descendant(of: card, matching: find.byType(Image)),
      );
      expect(
        images.any(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName == asset,
        ),
        isTrue,
      );
    }
    final cardsBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('destination-live')))
        .dy;
    final heroTop = tester
        .getTopLeft(find.byKey(const ValueKey('home-hero')))
        .dy;
    expect(heroTop - cardsBottom, greaterThanOrEqualTo(40));
  });

  testWidgets('catalog destinations use the approved scenic banners', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    final banner = find.byKey(const ValueKey('catalog-page-banner'));
    expect(banner, findsOneWidget);
    expect(
      tester
          .widgetList<Image>(
            find.descendant(of: banner, matching: find.byType(Image)),
          )
          .any(
            (image) =>
                image.image is AssetImage &&
                (image.image as AssetImage).assetName ==
                    'assets/destinations/hero-movies.png',
          ),
      isTrue,
    );
  });

  testWidgets('Movies show category chips above the poster grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _CategoryFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('catalog-category-chips')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('catalog-group-sidebar')), findsNothing);
    expect(find.byKey(const ValueKey('poster-grid')), findsOneWidget);
    expect(find.text('Fixture Adventure'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comedy'));
    await tester.pumpAndSettle();
    expect(find.text('Fixture Adventure'), findsNothing);
    expect(find.text('Fixture Comedy'), findsOneWidget);
  });

  testWidgets('Home hero supports directional controls and defers autoplay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    final initialTitle = tester.widget<Text>(
      find.byKey(const ValueKey('home-hero-title')),
    );
    expect(find.byKey(const ValueKey('home-hero-previous')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-hero-next')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byKey(const ValueKey('home-hero-next')));
    await tester.pump(const Duration(milliseconds: 350));
    final manuallySelectedTitle = tester.widget<Text>(
      find.byKey(const ValueKey('home-hero-title')).last,
    );
    expect(manuallySelectedTitle.data, isNot(initialTitle.data));

    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-hero-title')).last)
          .data,
      manuallySelectedTitle.data,
    );
  });

  testWidgets('Home hero supports horizontal swipe navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    final initialTitle = tester.widget<Text>(
      find.byKey(const ValueKey('home-hero-title')).last,
    );
    await tester.fling(
      find.byKey(const ValueKey('home-hero')),
      const Offset(-240, 0),
      900,
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-hero-title')).last)
          .data,
      isNot(initialTitle.data),
    );
  });

  testWidgets('Home hero respects reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    final initialTitle = tester.widget<Text>(
      find.byKey(const ValueKey('home-hero-title')),
    );

    await tester.pump(const Duration(seconds: 6));

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home-hero-title'))).data,
      initialTitle.data,
    );
  });

  testWidgets(
    'compact layouts expose all four destinations in bottom navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PlaylistImportController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(TviumApp(importController: controller));

      unawaited(controller.importSource(const _DesignFixtureSource()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('compact-navigation')), findsOneWidget);
      for (final label in const ['Home', 'Live TV', 'Movies', 'TV Shows']) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('compact-navigation')),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('wide navigation centers Tvium between its destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    final logo = find.byKey(const ValueKey<String>('tvium-brand-logo'));
    final logoCenter = tester.getCenter(logo);
    expect(logoCenter.dx, closeTo(640, 40));
    expect(
      tester.getCenter(find.widgetWithText(TextButton, 'Live TV')).dx,
      lessThan(logoCenter.dx),
    );
    expect(
      tester.getCenter(find.widgetWithText(TextButton, 'Movies')).dx,
      greaterThan(logoCenter.dx),
    );
  });
}

final class _FakePlaybackEngine implements PlaybackEngine {
  final List<Duration> seekPositions = <Duration>[];
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();
  PlaybackState _currentState = const PlaybackState();

  @override
  PlaybackState get currentState => _currentState;

  @override
  Stream<PlaybackState> get state => _states.stream;

  void emit(PlaybackState state) {
    _currentState = state;
    _states.add(state);
  }

  @override
  Future<void> dispose() => _states.close();

  @override
  Future<void> open(MediaSource source) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> selectAudioTrack(String id) async {}

  @override
  Future<void> selectSubtitleTrack(String id) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

final class _DesignFixtureSource implements M3uSource {
  const _DesignFixtureSource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 tvg-id="news" group-title="France News",Demo News',
    'https://stream.example.test/live/news.m3u8',
    '#EXTINF:-1 group-title="Movies",Demo Movie (2025)',
    'https://stream.example.test/vod/movie.mp4',
    '#EXTINF:-1 group-title="Series",Demo Show S01E01',
    'https://stream.example.test/series/episode.mkv',
    '#EXTINF:-1 group-title="Series",Demo Show 1x02',
    'https://stream.example.test/series/episode-2.mkv',
  ]);
}

final class _CountryFixtureSource implements M3uSource {
  const _CountryFixtureSource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 group-title="FR | News",Fixture France',
    'https://stream.example.test/fr.m3u8',
    '#EXTINF:-1 group-title="US | News",Fixture United States',
    'https://stream.example.test/us.m3u8',
    '#EXTINF:-1 group-title="AFR | News",Fixture Region',
    'https://stream.example.test/region.m3u8',
  ]);
}

final class _CategoryFixtureSource implements M3uSource {
  const _CategoryFixtureSource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 group-title="Adventure",Fixture Adventure',
    'https://stream.example.test/adventure.mp4',
    '#EXTINF:-1 group-title="Comedy",Fixture Comedy',
    'https://stream.example.test/comedy.mp4',
  ]);
}
