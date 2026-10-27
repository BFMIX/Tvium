import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/import/m3u_import_persistence.dart';
import 'package:tvium_app/features/import/playlist_import_controller.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

void main() {
  testWidgets('shows a distinct saving stage after playlist parsing', (
    tester,
  ) async {
    final persistence = _DelayedPersistence();
    final controller = PlaylistImportController(persistence: persistence);
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    final import = controller.importSource(
      const _MemorySource(),
      descriptor: const M3uSourceDescriptor.url(
        displayName: 'Fixture',
        location: 'https://playlist.example.test/list.m3u',
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.state.phase, PlaylistImportPhase.saving);
    expect(find.textContaining('Saving your library'), findsOneWidget);
    persistence.complete();
    await import;
    await tester.pump();
    expect(controller.state.phase, PlaylistImportPhase.ready);
  });

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
    expect(find.text('News'), findsWidgets);
    expect(find.text('Demo News'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Movies'));
    await tester.pumpAndSettle();
    expect(find.text('Cinema'), findsWidgets);
    final movieCard = find.descendant(
      of: find.byKey(const ValueKey('poster-grid')),
      matching: find.text('Demo Movie'),
    );
    expect(movieCard, findsOneWidget);
    await tester.tap(movieCard);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('metadata service is not configured'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Play now'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'TV Shows'));
    await tester.pumpAndSettle();
    expect(find.text('Series'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('poster-grid')),
        matching: find.text('Demo Show'),
      ),
      findsOneWidget,
    );
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

final class _DelayedPersistence implements M3uImportPersistence {
  final _saved = Completer<String>();

  @override
  Future<String> persist(
    M3uSourceDescriptor descriptor,
    List<M3uEntry> entries,
  ) => _saved.future;

  void complete() => _saved.complete('fixture-source');
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
