import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/artwork/artwork_image.dart';
import 'package:tvium_app/features/artwork/artwork_reference_store.dart';
import 'package:tvium_app/features/import/playlist_import_controller.dart';
import 'package:tvium_app/features/metadata/metadata_details.dart';
import 'package:tvium_app/features/metadata/metadata_gateway_client.dart';
import 'package:tvium_app/features/metadata/metadata_overlay_store.dart';
import 'package:tvium_app/features/updates/update_checker.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_m3u/tvium_m3u.dart';
import 'package:tvium_playback/tvium_playback.dart';

void main() {
  testWidgets('shows a loading surface before the saved library is ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      TviumApp(profileSourceRepository: _PendingLibraryRepository()),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('library-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-panel')), findsNothing);
  });
  testWidgets('restores metadata consent on startup', (tester) async {
    metadataEnabled.value = false;
    addTearDown(() => metadataEnabled.value = false);
    final consent = MetadataConsentStore(MemoryArtworkKeyValueStore());
    await consent.write(true);
    await tester.pumpWidget(TviumApp(metadataConsentStore: consent));
    await tester.pumpAndSettle();
    expect(metadataEnabled.value, isTrue);
  });

  testWidgets('release builds announce a newer published update', (
    tester,
  ) async {
    final checker = UpdateChecker(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(<Object>[
            <String, Object>{
              'tag_name': 'v1.0.0-alpha.7',
              'draft': false,
              'prerelease': true,
              'html_url':
                  'https://github.com/BFMIX/Tvium/releases/tag/v1.0.0-alpha.7',
            },
          ]),
          200,
        ),
      ),
    );
    addTearDown(checker.close);
    await tester.pumpWidget(
      TviumApp(updateChecker: checker, releaseTag: 'v1.0.0-alpha.6'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('v1.0.0-alpha.7 is available'), findsOneWidget);
  });
  testWidgets('release builds recheck updates on resume after an hour', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 22, 12);
    var requests = 0;
    final checker = UpdateChecker(
      client: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(checker.close);
    await tester.pumpWidget(
      TviumApp(
        updateChecker: checker,
        releaseTag: 'v1.0.0',
        updateClock: () => now,
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests, 1);

    now = now.add(const Duration(hours: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests, 2);
  });
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

  testWidgets('Home uses a blurred backdrop behind only three cards', (
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

    final backdrop = find.byKey(const ValueKey('home-page-backdrop'));
    final card = find.byKey(const ValueKey('destination-live'));
    expect(backdrop, findsOneWidget);
    expect(find.byKey(const ValueKey('home-hero')), findsNothing);
    expect(
      tester.getTopLeft(backdrop).dy,
      lessThan(tester.getTopLeft(card).dy),
    );
    expect(tester.getSize(backdrop).height, greaterThan(700));
    expect(find.byKey(const ValueKey('home-backdrop-blur')), findsOneWidget);
  });

  testWidgets('Home rotates fallback scenery without adding a carousel', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    final first = tester.widget<Image>(
      find.byKey(const ValueKey('home-backdrop-fallback')),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 700));
    final second = tester.widget<Image>(
      find.byKey(const ValueKey('home-backdrop-fallback')),
    );
    expect(second.image, isNot(first.image));
    expect(find.byKey(const ValueKey('home-hero')), findsNothing);
  });

  testWidgets('Home counts name each kind of content', (tester) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    for (final (key, label) in [
      ('destination-live', '1 TV channel'),
      ('destination-movies', '1 movie'),
      ('destination-shows', '1 TV series'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
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

  testWidgets('Live TV country sidebar filters only explicit country groups', (
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

    expect(find.byKey(const ValueKey('live-country-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-country-rail')), findsNothing);
    expect(find.byKey(const ValueKey('country-art-FR')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-group-sidebar')),
        matching: find.text('News'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('live-channel-list')),
        matching: find.text('Fixture France'),
      ),
      findsOneWidget,
    );
    expect(find.text('Fixture United States'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('country-US')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('live-channel-list')),
        matching: find.text('Fixture United States'),
      ),
      findsOneWidget,
    );
    expect(find.text('Fixture France'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('country-all')));
    await tester.pumpAndSettle();
    expect(find.text('Fixture Region'), findsOneWidget);
  });

  testWidgets('compact Live TV keeps countries in a horizontal rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
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
    expect(find.byKey(const ValueKey('live-country-sidebar')), findsNothing);
    expect(find.byKey(const ValueKey('country-flag-rail-FR')), findsOneWidget);
  });

  testWidgets('phone portrait keeps the Live TV player and rows compact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
    final row = find.byKey(const ValueKey('media-row-entry-1'));
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('catalog-player'))).height,
      lessThanOrEqualTo(180),
    );
    expect(tester.getSize(row).height, lessThanOrEqualTo(68));
    expect(
      tester.getSize(find.byKey(const ValueKey('compact-navigation'))).height,
      lessThanOrEqualTo(68),
    );
  });

  testWidgets('wide Live TV can search detected countries in the left pane', (
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

    await tester.enterText(
      find.byKey(const ValueKey('live-country-search')),
      'United',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('country-US')), findsOneWidget);
    expect(find.byKey(const ValueKey('country-FR')), findsNothing);
  });

  testWidgets('wide Live TV uses local flag artwork and category icons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
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

    expect(find.byKey(const ValueKey('country-flag-FR')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-category-icon-news')),
      findsOneWidget,
    );
  });

  testWidgets('Live channel artwork fits without an icon behind it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _LogoFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('media-row-entry-1'));
    final artwork = find.descendant(
      of: row,
      matching: find.byType(ArtworkImage),
    );
    expect(artwork, findsOneWidget);
    expect(tester.widget<ArtworkImage>(artwork).fit, BoxFit.contain);
    expect(
      find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('live-logo-fallback')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Live channel rows show the scenic backdrop through glass', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
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

    final row = find.byKey(const ValueKey('media-row-entry-1'));
    final card = find.descendant(of: row, matching: find.byType(Card));
    expect(tester.widget<Card>(card).color!.a, lessThan(1));
    expect(find.byKey(const ValueKey('live-channel-glass')), findsOneWidget);
  });

  testWidgets('wide Live TV searches channels inside the channel pane', (
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
    await tester.tap(find.byKey(const ValueKey('country-all')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('live-channel-search')),
      'United States',
    );
    await tester.pumpAndSettle();
    final channels = find.byKey(const ValueKey('live-channel-list'));
    expect(
      find.descendant(
        of: channels,
        matching: find.text('Fixture United States'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: channels, matching: find.text('Fixture France')),
      findsNothing,
    );
  });

  testWidgets('live preview details keep describing the playing channel', (
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
        playbackEngineFactory: _FakePlaybackEngine.new,
        playbackViewBuilder: (_) => const SizedBox(),
      ),
    );
    unawaited(controller.importSource(const _CountryFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-row-entry-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('country-US')));
    await tester.pumpAndSettle();

    final info = find.byKey(const ValueKey('live-preview-info'));
    expect(
      find.descendant(of: info, matching: find.text('Fixture France')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: info, matching: find.text('Fixture United States')),
      findsNothing,
    );
  });

  testWidgets('wide Live TV uses the four zones from the approved design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
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

    final country = find.byKey(const ValueKey('live-country-sidebar'));
    final groups = find.byKey(const ValueKey('catalog-group-sidebar'));
    final channels = find.byKey(const ValueKey('live-channel-list'));
    final preview = find.byKey(const ValueKey('catalog-player'));
    expect(country, findsOneWidget);
    expect(groups, findsOneWidget);
    expect(channels, findsOneWidget);
    expect(preview, findsOneWidget);
    expect(find.byKey(const ValueKey('live-preview-info')), findsOneWidget);
    expect(
      tester.getTopLeft(country).dx,
      lessThan(tester.getTopLeft(groups).dx),
    );
    expect(
      tester.getTopLeft(groups).dx,
      lessThan(tester.getTopLeft(channels).dx),
    );
    expect(
      tester.getTopLeft(channels).dx,
      lessThan(tester.getTopLeft(preview).dx),
    );
  });

  testWidgets('Live TV backdrop extends behind the wide header', (
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
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    final backdrop = find.byKey(const ValueKey('live-page-background'));
    final logo = find.byKey(const ValueKey('tvium-brand-logo'));
    expect(backdrop, findsOneWidget);
    expect(
      tester.getTopLeft(backdrop).dy,
      lessThan(tester.getTopLeft(logo).dy),
    );
    expect(tester.getSize(backdrop).height, greaterThan(700));
  });

  testWidgets('wide Live TV keeps the country zone for unclassified groups', (
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
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('live-country-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('country-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-group-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-channel-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-player')), findsOneWidget);
  });

  testWidgets('Live TV uses a page backdrop and preview guide actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
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

    expect(find.byKey(const ValueKey('live-page-background')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-page-banner')), findsNothing);
    expect(find.byKey(const ValueKey('live-preview-guide')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-preview-play')), findsOneWidget);
  });

  testWidgets('wide Live TV remains usable with double accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _CountryFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('live-country-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-group-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-channel-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-player')), findsOneWidget);
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

  testWidgets('phone landscape keeps channels beside the player', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(932, 430);
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
    final channels = find.byKey(const ValueKey('live-channel-list'));
    final player = find.byKey(const ValueKey('catalog-player'));
    expect(channels, findsOneWidget);
    expect(player, findsOneWidget);
    expect(tester.getSize(channels).height, greaterThan(80));
    expect(
      tester.getTopLeft(player).dx,
      greaterThan(tester.getTopLeft(channels).dx),
    );
  });

  testWidgets('Live TV player opens a full screen view with channel controls', (
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
    unawaited(controller.importSource(const _ZappingFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-row-entry-1')));
    await tester.pumpAndSettle();

    final previewControls = find.byKey(const ValueKey('live-preview-controls'));
    final previewPrevious = find.byKey(const ValueKey('live-previous-channel'));
    final previewNext = find.byKey(const ValueKey('live-next-channel'));
    expect(
      (tester.getCenter(previewPrevious).dx +
              tester.getCenter(previewNext).dx) /
          2,
      closeTo(tester.getCenter(previewControls).dx, 1),
    );
    expect(
      find.byKey(const ValueKey('live-player-fullscreen')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('live-player-fullscreen')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('live-fullscreen-player')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('live-previous-channel')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-next-channel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('live-fullscreen-volume')),
      findsOneWidget,
    );
    expect(find.byTooltip('Exit full screen'), findsOneWidget);
    final fullScreen = find.byKey(const ValueKey('live-fullscreen-player'));
    final controls = find.byKey(const ValueKey('live-fullscreen-controls'));
    final volume = find.byKey(const ValueKey('live-fullscreen-volume'));
    expect(
      (tester
                  .getCenter(
                    find.byKey(const ValueKey('live-previous-channel')),
                  )
                  .dx +
              tester
                  .getCenter(find.byKey(const ValueKey('live-next-channel')))
                  .dx) /
          2,
      closeTo(tester.getCenter(controls).dx, 1),
    );
    expect(tester.getSize(controls).height, 56);
    expect(
      tester.getCenter(volume).dy,
      greaterThan(tester.getBottomLeft(fullScreen).dy - 120),
    );
    await tester.tap(find.byKey(const ValueKey('live-fullscreen-exit')));
    await tester.pumpAndSettle();
  });

  testWidgets('Live TV F shortcut uses the same full screen player', (
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
    unawaited(controller.importSource(const _ZappingFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-row-entry-1')));
    await tester.pumpAndSettle();
    Focus.of(
      tester.element(find.byKey(const ValueKey('live-preview-controls'))),
    ).requestFocus();
    await tester.pump();
    expect(
      Focus.of(
        tester.element(find.byKey(const ValueKey('live-preview-controls'))),
      ).hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('live-fullscreen-player')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('live-preview-controls')), findsNothing);
    expect(
      find.byKey(const ValueKey('live-fullscreen-controls')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-fullscreen-player')), findsNothing);
  });

  testWidgets('Live TV full screen controls hide until pointer activity', (
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
    unawaited(controller.importSource(const _ZappingFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-row-entry-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('live-player-fullscreen')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('live-fullscreen-controls')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    expect(
      find.byKey(const ValueKey('live-fullscreen-controls')),
      findsNothing,
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: const Offset(300, 300));
    await gesture.moveTo(const Offset(320, 320));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('live-fullscreen-controls')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
  });

  testWidgets('Live TV player zaps through visible playable channels', (
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
    unawaited(controller.importSource(const _ZappingFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-row-entry-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('live-next-channel')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-player')),
        matching: find.text('Channel Two'),
      ),
      findsWidgets,
    );
    await tester.tap(find.byKey(const ValueKey('live-previous-channel')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-player')),
        matching: find.text('Channel One'),
      ),
      findsWidgets,
    );
    await tester.tap(find.byKey(const ValueKey('live-previous-channel')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-player')),
        matching: find.text('Channel Three'),
      ),
      findsWidgets,
    );
  });

  testWidgets('focused Live TV player handles remote up and down keys', (
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
    unawaited(controller.importSource(const _ZappingFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-row-entry-1')));
    await tester.pumpAndSettle();

    Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byKey(const ValueKey('live-player-focus')),
              matching: find.byType(Container),
            )
            .first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-player')),
        matching: find.text('Channel Two'),
      ),
      findsWidgets,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-player')),
        matching: find.text('Channel One'),
      ),
      findsWidgets,
    );
  });

  testWidgets('Live TV quick switcher searches visible channels', (
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
    unawaited(controller.importSource(const _ZappingFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-row-entry-1')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('live-channel-switcher-button')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-channel-switcher')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('live-channel-switcher-search')),
      'unmatched',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching channels'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-channel-switcher')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('live-channel-switcher-search')),
      'three',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('switch-channel-entry-3')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('switch-channel-entry-2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('switch-channel-entry-3')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-player')),
        matching: find.text('Channel Three'),
      ),
      findsWidgets,
    );
    await tester.tap(
      find.byKey(const ValueKey('live-channel-switcher-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('live-channel-switcher-search')),
      'two',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-channel-switcher')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-player')),
        matching: find.text('Channel Two'),
      ),
      findsWidgets,
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

  testWidgets('Movies and TV Shows extend scenery behind the header', (
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
    expect(
      find.byKey(const ValueKey('catalog-page-background')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'TV Shows'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('catalog-page-background')),
      findsOneWidget,
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

  for (final destination in <String>['movies', 'shows']) {
    testWidgets('wide $destination places categories beside the poster grid', (
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
      await tester.tap(find.byKey(ValueKey('destination-$destination')));
      await tester.pumpAndSettle();

      final sidebar = find.byKey(const ValueKey('catalog-group-sidebar'));
      final grid = find.byKey(const ValueKey('poster-grid'));
      expect(sidebar, findsOneWidget);
      expect(grid, findsOneWidget);
      expect(
        find.byKey(const ValueKey('catalog-category-chips')),
        findsNothing,
      );
      expect(
        tester.getTopLeft(sidebar).dx,
        lessThan(tester.getTopLeft(grid).dx),
      );
    });
  }

  for (final destination in <String>['movies', 'shows']) {
    testWidgets('phone landscape keeps $destination posters compact', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(932, 430);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PlaylistImportController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(TviumApp(importController: controller));
      unawaited(controller.importSource(const _DesignFixtureSource()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('destination-$destination')));
      await tester.pumpAndSettle();

      final grid = find.byKey(const ValueKey('poster-grid'));
      expect(grid, findsOneWidget);
      final delegate =
          tester.widget<GridView>(grid).gridDelegate
              as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.maxCrossAxisExtent, lessThanOrEqualTo(160));
      expect(tester.getSize(grid).height, greaterThan(180));
    });
  }

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

  testWidgets('movie full screen exposes seek and keyboard stepping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    final playback = _FakePlaybackEngine();
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        profileSourceRepository: InMemoryProfileSourceRepository(),
        playbackEngineFactory: () => playback,
        playbackViewBuilder: (_) => const SizedBox(),
      ),
    );
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('media-card-movie')));
    await tester.tap(find.byKey(const ValueKey('media-card-movie')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Play now'));
    await tester.pumpAndSettle();
    playback.emit(
      const PlaybackState(
        phase: PlaybackPhase.playing,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 2),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('live-player-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fullscreen-seek')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(playback.seekPositions.last, const Duration(seconds: 40));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
  });

  testWidgets('movie details place the real poster beside the title', (
    tester,
  ) async {
    metadataEnabled.value = false;
    addTearDown(() => metadataEnabled.value = false);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _HeroArtworkFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-feature')),
        matching: find.text('View details'),
      ),
    );
    await tester.pumpAndSettle();

    final poster = find.byKey(const ValueKey('title-details-poster'));
    final title = find.byKey(const ValueKey('title-details-heading'));
    expect(poster, findsOneWidget);
    expect(title, findsOneWidget);
    expect(
      find.byKey(const ValueKey('title-details-backdrop')),
      findsOneWidget,
    );
    expect(tester.getSize(poster).width, greaterThanOrEqualTo(200));
    expect(tester.getTopLeft(poster).dx, lessThan(tester.getTopLeft(title).dx));
    expect(find.text('Online details are off in Settings.'), findsOneWidget);
  });

  testWidgets('movie details show online information without another dialog', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('media-card-movie')));
    await tester.tap(find.byKey(const ValueKey('media-card-movie')));
    await tester.pumpAndSettle();

    expect(find.text('Online details are off in Settings.'), findsOneWidget);
    expect(find.byKey(const ValueKey('title-online-info')), findsNothing);
  });

  testWidgets('local series details use a neutral poster beside seasons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _EpisodeStillFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-shows')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('poster-grid')),
        matching: find.text('Fixture Show'),
      ),
    );
    await tester.pumpAndSettle();

    final poster = find.byKey(const ValueKey('title-details-poster'));
    final season = find.byKey(const ValueKey('season-1'));
    expect(poster, findsOneWidget);
    expect(
      find.descendant(of: poster, matching: find.byType(ArtworkImage)),
      findsNothing,
    );
    expect(season, findsOneWidget);
    expect(
      tester.getTopLeft(poster).dx,
      lessThan(tester.getTopLeft(season).dx),
    );
    expect(find.text('Online details are off in Settings.'), findsOneWidget);
  });

  testWidgets('series details show online information without another dialog', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-shows')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo Show'));
    await tester.pumpAndSettle();

    expect(find.text('Online details are off in Settings.'), findsOneWidget);
    expect(find.byKey(const ValueKey('title-online-info')), findsNothing);
  });

  testWidgets('compact movie details stack the poster above the title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _HeroArtworkFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('media-card-entry-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-card-entry-2')));
    await tester.pumpAndSettle();

    final poster = find.byKey(const ValueKey('title-details-poster'));
    final title = find.byKey(const ValueKey('title-details-heading'));
    expect(poster, findsOneWidget);
    expect(title, findsOneWidget);
    expect(tester.getTopLeft(poster).dy, lessThan(tester.getTopLeft(title).dy));
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

  testWidgets('resumable local episodes appear in TV Shows', (tester) async {
    final repository = InMemoryProfileSourceRepository();
    final profile = await repository.ensureDefaultProfile();
    await repository.recordPlayback(
      PlaybackHistoryEntry(
        media: MediaLocator(
          profileId: profile.id,
          sourceId: 'session.m3u',
          entryId: 'entry-3',
        ),
        lastPlayedAtUtc: DateTime.utc(2026, 10, 19),
        position: const Duration(seconds: 30),
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
    await tester.tap(find.byKey(const ValueKey('destination-shows')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('shows-continue-watching')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('continue-artwork-entry-3')),
      findsOneWidget,
    );
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('continue-progress-entry-3')),
    );
    expect(progress.value, closeTo(0.25, 0.001));
  });

  testWidgets('opted-in Home uses a verified backdrop from metadata', (
    tester,
  ) async {
    metadataEnabled.value = true;
    addTearDown(() => metadataEnabled.value = false);
    final consent = MetadataConsentStore(MemoryArtworkKeyValueStore());
    await consent.write(true);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient(
        (_) async => http.Response(
          '{"candidates":[{"id":"7","provider":"tmdb","title":"Demo Movie","kind":"movie","year":2025,"backdropUrl":"https://image.tmdb.org/t/p/w1280/backdrop.jpg","license":"TMDB terms"}]}',
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        metadataGatewayClient: client,
        metadataOverlayStore: MetadataOverlayStore(
          MemoryArtworkKeyValueStore(),
        ),
        metadataConsentStore: consent,
      ),
    );
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-page-backdrop')),
        matching: find.byType(ArtworkImage),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'opted-in Movies enriches visible posters without opening details',
    (tester) async {
      metadataEnabled.value = true;
      addTearDown(() => metadataEnabled.value = false);
      final consent = MetadataConsentStore(MemoryArtworkKeyValueStore());
      await consent.write(true);
      final requested = <String>[];
      final client = MetadataGatewayClient(
        endpoint: Uri.parse('https://metadata.example.test'),
        client: MockClient((request) async {
          final title =
              (jsonDecode(request.body) as Map<String, dynamic>)['title']
                  as String;
          requested.add(title);
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'id': title == 'Second Movie' ? '2' : '1',
                  'provider': 'tmdb',
                  'title': title,
                  'kind': 'movie',
                  'year': 2025,
                  'posterUrl': 'https://image.tmdb.org/t/p/w500/poster.jpg',
                  'license': 'TMDB terms',
                },
              ],
            }),
            200,
          );
        }),
      );
      final controller = PlaylistImportController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        TviumApp(
          importController: controller,
          metadataGatewayClient: client,
          metadataOverlayStore: MetadataOverlayStore(
            MemoryArtworkKeyValueStore(),
          ),
          metadataConsentStore: consent,
        ),
      );
      unawaited(controller.importSource(const _MetadataGridFixtureSource()));
      await tester.pumpAndSettle();
      expect(requested, isNot(contains('Second Movie')));
      await tester.tap(find.byKey(const ValueKey('destination-movies')));
      await tester.pumpAndSettle();
      expect(requested, contains('Second Movie'));
      expect(find.byKey(const ValueKey('poster-grid')), findsOneWidget);
    },
  );

  testWidgets('scrolling to a movie enriches its poster automatically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    metadataEnabled.value = true;
    addTearDown(() => metadataEnabled.value = false);
    final consent = MetadataConsentStore(MemoryArtworkKeyValueStore());
    await consent.write(true);
    final requested = <String>[];
    final client = MetadataGatewayClient(
      endpoint: Uri.parse('https://metadata.example.test'),
      client: MockClient((request) async {
        final title =
            (jsonDecode(request.body) as Map<String, dynamic>)['title']
                as String;
        requested.add(title);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'id': title,
                'provider': 'tmdb',
                'title': title,
                'kind': 'movie',
                'year': 2025,
                'posterUrl': 'https://image.tmdb.org/t/p/w500/poster.jpg',
                'license': 'TMDB terms',
              },
            ],
          }),
          200,
        );
      }),
    );
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        metadataGatewayClient: client,
        metadataOverlayStore: MetadataOverlayStore(
          MemoryArtworkKeyValueStore(),
        ),
        metadataConsentStore: consent,
      ),
    );
    unawaited(controller.importSource(const _LongMetadataGridFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movies').first);
    await tester.pumpAndSettle();
    expect(requested, isNot(contains('Eighth Movie')));

    await tester.drag(
      find.byKey(const ValueKey('poster-grid')),
      const Offset(0, -680),
    );
    await tester.pumpAndSettle();
    for (var index = 0; index < 10; index++) {
      await tester.pump(const Duration(seconds: 2));
    }
    expect(requested, contains('Eighth Movie'));
  });

  testWidgets('Movies feature a real poster without a scenic banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _HeroArtworkFixtureSource()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    final feature = find.byKey(const ValueKey('catalog-feature'));
    expect(feature, findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-page-banner')), findsNothing);
    expect(
      find.descendant(of: feature, matching: find.text('Illustrated Movie')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('catalog-feature-poster')),
      findsOneWidget,
    );
  });

  testWidgets('Movies feature uses verified backdrop and poster', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    metadataEnabled.value = true;
    addTearDown(() => metadataEnabled.value = false);
    final consent = MetadataConsentStore(MemoryArtworkKeyValueStore());
    await consent.write(true);
    final store = MetadataOverlayStore(MemoryArtworkKeyValueStore());
    await store.write(
      sourceId: 'session.m3u',
      entryId: 'entry-2',
      originalTitle: 'Demo Movie (2025)',
      kind: MediaKind.movie,
      overlay: MetadataOverlay(
        provider: 'tmdb',
        providerId: '7',
        title: 'Demo Movie',
        overview: 'A synthetic film synopsis.',
        posterUri: Uri.parse('https://image.tmdb.org/t/p/w500/poster.jpg'),
        backdropUri: Uri.parse('https://image.tmdb.org/t/p/w1280/backdrop.jpg'),
        verified: true,
      ),
    );
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        metadataOverlayStore: store,
        metadataConsentStore: consent,
      ),
    );
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('catalog-feature-backdrop')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-page-background')),
        matching: find.byType(ArtworkImage),
      ),
      findsOneWidget,
    );
    final poster = tester.widget<ArtworkImage>(
      find.byKey(const ValueKey('catalog-feature-poster')),
    );
    expect(poster.uri?.host, 'image.tmdb.org');
    expect(find.text('A synthetic film synopsis.'), findsOneWidget);
  });

  testWidgets('Movies grid uses a cached verified poster after restart', (
    tester,
  ) async {
    metadataEnabled.value = true;
    addTearDown(() => metadataEnabled.value = false);
    final consent = MetadataConsentStore(MemoryArtworkKeyValueStore());
    await consent.write(true);
    final store = MetadataOverlayStore(MemoryArtworkKeyValueStore());
    await store.write(
      sourceId: 'session.m3u',
      entryId: 'entry-2',
      originalTitle: 'Demo Movie (2025)',
      kind: MediaKind.movie,
      overlay: MetadataOverlay(
        provider: 'tmdb',
        providerId: '7',
        title: 'Demo Movie',
        posterUri: Uri.parse('https://image.tmdb.org/t/p/w500/poster.jpg'),
        verified: true,
      ),
    );
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        metadataOverlayStore: store,
        metadataConsentStore: consent,
      ),
    );
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('media-card-movie'));
    final artwork = tester.widget<ArtworkImage>(
      find.descendant(of: card, matching: find.byType(ArtworkImage)),
    );
    expect(artwork.role, 'verified-poster');
    expect(artwork.uri?.host, 'image.tmdb.org');
  });

  testWidgets('poster cards use a translucent surface in the library', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();

    final card = tester.widget<Card>(
      find.descendant(
        of: find.byKey(const ValueKey('media-card-movie')),
        matching: find.byType(Card),
      ),
    );
    expect(card.color?.a, lessThan(1));
  });

  testWidgets('compact Movies and TV Shows open without a feature carousel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
    expect(find.byKey(const ValueKey('catalog-feature')), findsNothing);
    expect(find.byKey(const ValueKey('poster-grid')), findsOneWidget);

    await tester.tap(find.text('TV Shows').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('catalog-feature')), findsNothing);
    expect(find.byKey(const ValueKey('poster-grid')), findsOneWidget);
  });

  testWidgets('TV Shows feature does not use an episode still as a poster', (
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
    await tester.tap(find.byKey(const ValueKey('destination-shows')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('catalog-feature')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-feature-poster')), findsNothing);
  });

  testWidgets('TV Shows feature uses a confirmed series poster', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    metadataEnabled.value = true;
    addTearDown(() => metadataEnabled.value = false);
    final consent = MetadataConsentStore(MemoryArtworkKeyValueStore());
    await consent.write(true);
    final store = MetadataOverlayStore(MemoryArtworkKeyValueStore());
    await store.write(
      sourceId: 'session.m3u',
      entryId: 'local-series:session.m3u:fixture-show',
      originalTitle: 'Fixture Show',
      kind: MediaKind.episode,
      overlay: MetadataOverlay(
        provider: 'tmdb',
        providerId: '8',
        title: 'Fixture Show',
        posterUri: Uri.parse('https://image.tmdb.org/t/p/w500/show.jpg'),
        verified: true,
      ),
    );
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        metadataOverlayStore: store,
        metadataConsentStore: consent,
      ),
    );
    unawaited(controller.importSource(const _EpisodeStillFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-shows')));
    await tester.pumpAndSettle();

    final feature = find.byKey(const ValueKey('catalog-feature'));
    expect(
      find.descendant(
        of: feature,
        matching: find.byKey(const ValueKey('catalog-feature-poster')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('TV Shows grid does not promote an episode still to series art', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _EpisodeStillFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-shows')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('catalog-series-placeholder')),
      findsOneWidget,
    );
  });

  testWidgets('TV Shows grid replaces an episode still with verified art', (
    tester,
  ) async {
    metadataEnabled.value = true;
    addTearDown(() => metadataEnabled.value = false);
    final consent = MetadataConsentStore(MemoryArtworkKeyValueStore());
    await consent.write(true);
    final store = MetadataOverlayStore(MemoryArtworkKeyValueStore());
    await store.write(
      sourceId: 'session.m3u',
      entryId: 'local-series:session.m3u:fixture-show',
      originalTitle: 'Fixture Show',
      kind: MediaKind.episode,
      overlay: MetadataOverlay(
        provider: 'tmdb',
        providerId: '8',
        title: 'Fixture Show',
        posterUri: Uri.parse('https://image.tmdb.org/t/p/w500/show.jpg'),
        verified: true,
      ),
    );
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TviumApp(
        importController: controller,
        metadataOverlayStore: store,
        metadataConsentStore: consent,
      ),
    );
    unawaited(controller.importSource(const _EpisodeStillFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-shows')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('catalog-series-placeholder')),
      findsNothing,
    );
    final artwork = tester.widget<ArtworkImage>(
      find.descendant(
        of: find.byKey(const ValueKey('poster-grid')),
        matching: find.byType(ArtworkImage),
      ),
    );
    expect(artwork.role, 'verified-poster');
  });

  testWidgets('compact Movies show category chips above the poster grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
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
    final grid = find.byKey(const ValueKey('poster-grid'));
    expect(
      find.descendant(of: grid, matching: find.text('Fixture Adventure')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comedy'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: grid, matching: find.text('Fixture Adventure')),
      findsNothing,
    );
    expect(
      find.descendant(of: grid, matching: find.text('Fixture Comedy')),
      findsOneWidget,
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

  testWidgets('720p TV header keeps search clear of TV Shows', (tester) async {
    tester.view.physicalSize = const Size(1000, 720);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();

    final shows = find.widgetWithText(TextButton, 'TV Shows');
    final search = find.byTooltip('Search');
    expect(shows, findsOneWidget);
    expect(search, findsOneWidget);
    expect(
      tester.getTopRight(shows).dx,
      lessThan(tester.getTopLeft(search).dx),
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

final class _ZappingFixtureSource implements M3uSource {
  const _ZappingFixtureSource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 group-title="News",Channel One',
    'https://stream.example.test/live/one.m3u8',
    '#EXTINF:-1 group-title="News",Channel Two',
    'https://stream.example.test/live/two.m3u8',
    '#EXTINF:-1 group-title="News",Channel Three',
    'https://stream.example.test/live/three.m3u8',
  ]);
}

final class _EpisodeStillFixtureSource implements M3uSource {
  const _EpisodeStillFixtureSource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 tvg-logo="https://art.example.test/episode-still.jpg" group-title="Series",Fixture Show S01E01',
    'https://stream.example.test/series/episode.mkv',
  ]);
}

final class _HeroArtworkFixtureSource implements M3uSource {
  const _HeroArtworkFixtureSource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 group-title="Movies",Plain Movie',
    'https://stream.example.test/vod/plain.mp4',
    '#EXTINF:-1 tvg-logo="https://art.example.test/illustrated.jpg" group-title="Movies",Illustrated Movie',
    'https://stream.example.test/vod/illustrated.mp4',
  ]);
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

final class _MetadataGridFixtureSource implements M3uSource {
  const _MetadataGridFixtureSource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 tvg-logo="https://art.example.test/first.jpg" group-title="Movies",First Movie (2025)',
    'https://stream.example.test/vod/first.mp4',
    '#EXTINF:-1 group-title="Movies",Second Movie (2025)',
    'https://stream.example.test/vod/second.mp4',
  ]);
}

final class _LongMetadataGridFixtureSource implements M3uSource {
  const _LongMetadataGridFixtureSource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    for (final (index, title) in <String>[
      'First Movie',
      'Second Movie',
      'Third Movie',
      'Fourth Movie',
      'Fifth Movie',
      'Sixth Movie',
      'Seventh Movie',
      'Eighth Movie',
    ].indexed) ...<String>[
      '#EXTINF:-1 group-title="Movies",$title (2025)',
      'https://stream.example.test/vod/$index.mp4',
    ],
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

final class _LogoFixtureSource implements M3uSource {
  const _LogoFixtureSource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 tvg-logo="https://art.example.test/wide-logo.png" group-title="FR | News",Fixture One',
    'https://stream.example.test/fr.m3u8',
    '#EXTINF:-1 group-title="US | Sports",Fixture Two',
    'https://stream.example.test/us.m3u8',
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

final class _PendingLibraryRepository implements ProfileSourceRepository {
  final _pending = Completer<UserProfile>();

  @override
  Future<UserProfile> ensureDefaultProfile() => _pending.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
