import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/import/playlist_import_controller.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

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

  testWidgets('movie cards open title details before playback', (tester) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _DesignFixtureSource()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-movies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media-card-movie')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('title-details')), findsOneWidget);
    expect(find.text('Demo Movie'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
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
  ]);
}
