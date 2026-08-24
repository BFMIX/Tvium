import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_app/features/import/playlist_import_controller.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

void main() {
  testWidgets('renders imported groups and bounded channel rows', (
    tester,
  ) async {
    final controller = PlaylistImportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TviumApp(importController: controller));

    unawaited(controller.importSource(const _MemorySource()));
    await tester.pumpAndSettle();

    expect(find.text('3 items ready'), findsOneWidget);
    expect(find.text('LIVE TV'), findsOneWidget);
    expect(find.text('MOVIES'), findsOneWidget);
    expect(find.text('TV SHOWS'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Demo News'), findsOneWidget);
    expect(find.text('Cinema'), findsOneWidget);
    expect(find.text('Demo Movie (2025)'), findsOneWidget);
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
