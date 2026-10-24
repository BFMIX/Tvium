import 'package:test/test.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

void main() {
  group('M3uParser', () {
    test('treats missing and blank logo attributes as no artwork', () {
      M3uEntry entry(Map<String, String> attributes) => M3uEntry(
        id: 'synthetic',
        originalExtInf: '#EXTINF:-1,Synthetic',
        originalName: 'Synthetic',
        originalUri: Uri.parse('https://stream.example.test/movie.mp4'),
        attributes: attributes,
        kind: MediaKind.movie,
      );

      expect(entry(const <String, String>{}).logoUri, isNull);
      expect(entry(const <String, String>{'tvg-logo': '  '}).logoUri, isNull);
    });

    test('preserves source fields and unknown EXTINF attributes', () async {
      const extInf =
          '#EXTINF:-1 tvg-id="news.fr" tvg-name="FR | News FHD" '
          'tvg-logo="https://images.example.test/news.png" '
          'group-title="FR | NEWS" vendor-tag="kept value",FR | News FHD';
      final events = await const M3uParser(batchSize: 1)
          .parse(
            Stream<String>.fromIterable(<String>[
              '#EXTM3U',
              extInf,
              'https://stream.example.test/live/news.m3u8',
            ]),
          )
          .toList();

      final batch = events.whereType<M3uBatch>().single;
      final entry = batch.entries.single;

      expect(entry.originalExtInf, extInf);
      expect(entry.originalName, 'FR | News FHD');
      expect(
        entry.originalUri.toString(),
        'https://stream.example.test/live/news.m3u8',
      );
      expect(entry.attributes['vendor-tag'], 'kept value');
      expect(entry.groupTitle, 'FR | NEWS');
      expect(entry.logoUri.toString(), 'https://images.example.test/news.png');
      expect(entry.kind, MediaKind.live);
    });

    test('reports a missing URI and continues with the next entry', () async {
      final events = await const M3uParser()
          .parse(
            Stream<String>.fromIterable(<String>[
              '#EXTM3U',
              '#EXTINF:-1 group-title="News",Broken channel',
              '#EXTINF:-1 group-title="Sports",Working channel',
              'https://stream.example.test/live/working.m3u8',
            ]),
          )
          .toList();

      final warnings = events.whereType<M3uWarning>().toList();
      final entries = events
          .whereType<M3uBatch>()
          .expand((batch) => batch.entries)
          .toList();
      final completed = events.whereType<M3uCompleted>().single;

      expect(warnings, hasLength(1));
      expect(warnings.single.lineNumber, 2);
      expect(warnings.single.message, 'Entry has no stream URI');
      expect(entries.single.originalName, 'Working channel');
      expect(completed.summary.parsedEntries, 1);
      expect(completed.summary.warningCount, 1);
    });

    test(
      'classifies file and episode patterns without deleting uncertainty',
      () async {
        final events = await const M3uParser()
            .parse(
              Stream<String>.fromIterable(<String>[
                '#EXTM3U',
                '#EXTINF:-1 group-title="Cinema",Example Movie (2025)',
                'https://stream.example.test/vod/movie.mp4',
                '#EXTINF:-1 group-title="Series",Example Show S01E02',
                'https://stream.example.test/series/episode.mkv',
                '#EXTINF:-1,Mystery item',
                'https://stream.example.test/resource',
              ]),
            )
            .toList();

        final entries = events
            .whereType<M3uBatch>()
            .expand((batch) => batch.entries)
            .toList();

        expect(entries.map((entry) => entry.kind), <MediaKind>[
          MediaKind.movie,
          MediaKind.episode,
          MediaKind.unclassified,
        ]);
        expect(entries.last.originalName, 'Mystery item');
      },
    );

    test('emits bounded batches and a final summary', () async {
      final lines = <String>['#EXTM3U'];
      for (var index = 0; index < 5; index++) {
        lines
          ..add('#EXTINF:-1 group-title="Demo",Channel $index')
          ..add('https://stream.example.test/live/$index.m3u8');
      }

      final events = await const M3uParser(batchSize: 2)
          .parse(Stream<String>.fromIterable(lines))
          .toList();
      final batches = events.whereType<M3uBatch>().toList();

      expect(batches.map((batch) => batch.entries.length), <int>[2, 2, 1]);
      expect(events.whereType<M3uCompleted>().single.summary.parsedEntries, 5);
    });
  });
}
