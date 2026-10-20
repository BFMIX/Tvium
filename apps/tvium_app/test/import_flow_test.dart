import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/import/playlist_import_controller.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

void main() {
  testWidgets('renders imported groups in their catalog destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _MemorySource()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('destination-live')), findsOneWidget);
    expect(find.byKey(const ValueKey('destination-movies')), findsOneWidget);
    expect(find.byKey(const ValueKey('destination-shows')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-channel-list')), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Demo News'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Movies'));
    await tester.pumpAndSettle();
    expect(find.text('Cinema'), findsWidgets);
    expect(find.text('Demo Movie'), findsOneWidget);
    await tester.tap(find.text('Demo Movie'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Online descriptions and ratings are optional and do not affect playback.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Play now'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'TV Shows'));
    await tester.pumpAndSettle();
    expect(find.text('Series'), findsWidgets);
    expect(find.text('Demo Show'), findsOneWidget);
  });

  testWidgets('keeps live TV reachable in compact layouts', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _MemorySource()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live TV').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('page-live')), findsOneWidget);
    expect(find.text('Demo News'), findsOneWidget);
  });

  testWidgets('opens playlist import choices from library settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));
    unawaited(controller.importSource(const _MemorySource()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-page-playlists')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-playlist')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-local-m3u')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-m3u-url')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-xtream')), findsOneWidget);
  });
}

final class _MemorySource implements M3uSource {
  const _MemorySource();

  @override
  Stream<String> readLines() => Stream<String>.fromIterable(<String>[
    '#EXTM3U',
    '#EXTINF:-1 tvg-id="news" group-title="News",Demo News',
    'https://stream.example.test/live/news.m3u8',
    '#EXTINF:-1 group-title="Cinema",Demo Movie (2025)',
    'https://stream.example.test/vod/movie.mp4',
    '#EXTINF:-1 group-title="Series",Demo Show S01E01',
    'https://stream.example.test/series/episode.mkv',
  ]);
}
