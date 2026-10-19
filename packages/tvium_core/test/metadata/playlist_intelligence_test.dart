import 'package:test/test.dart';
import 'package:tvium_core/tvium_core.dart';

void main() {
  const normalizer = PlaylistTitleNormalizer();
  const matcher = MetadataMatcher();
  group('Local title normalization', () {
    test('extracts explicit metadata while preserving the original', () {
      const original = '  [FR]  Example Movie (2024) [1080P]  ';
      final result = normalizer.normalize(original, kind: MediaKind.movie);
      expect(result.originalTitle, original);
      expect(result.title, 'Example Movie');
      expect(result.year, 2024);
      expect(result.language, 'fr');
      expect(result.quality, '1080P');
    });
    test('does not mistake ordinary title words or years for tags', () {
      for (final title in ['It', 'Up', '1917', 'HD Radio', 'Studio 2024']) {
        expect(normalizer.normalize(title).title, title);
      }
      expect(
        normalizer.normalize('Example [DIRECTOR CUT]').title,
        'Example [DIRECTOR CUT]',
      );
    });
    test('keeps repeated languages consistent and reports conflicts', () {
      expect(normalizer.normalize('[FR] Example [FR]').warnings, isEmpty);
      final conflict = normalizer.normalize('[FR] Example [EN]');
      expect(conflict.warnings, contains('Conflicting language tags'));
      expect(conflict.language, isNull);
    });
    test('extracts episode coordinates but respects explicit live kind', () {
      final result = normalizer.normalize('Example (2020) S02E013 [HD]');
      expect(result.kind, MediaKind.episode);
      expect(result.title, 'Example');
      expect(result.year, 2020);
      expect(result.season, 2);
      expect(result.episode, 13);
      final live = normalizer.normalize(
        'Example S02E013 (2020)',
        kind: MediaKind.live,
      );
      expect(live.title, 'Example S02E013 (2020)');
      expect(live.year, isNull);
    });
    test('extracts common provider episode formats consistently', () {
      final cases = <String, (String, int, int)>{
        'Example 1x02': ('Example', 1, 2),
        'Example - Season 3 Episode 7': ('Example', 3, 7),
        'Example - Saison 4 Épisode 9': ('Example', 4, 9),
        'Example - Temporada 2 Episodio 5': ('Example', 2, 5),
      };
      for (final MapEntry(key: title, value: expected) in cases.entries) {
        final result = normalizer.normalize(title);
        expect(result.title, expected.$1, reason: title);
        expect(result.season, expected.$2, reason: title);
        expect(result.episode, expected.$3, reason: title);
        expect(result.kind, MediaKind.episode, reason: title);
      }
    });
    test('rejects episode zero and never returns an empty derived title', () {
      expect(
        normalizer.normalize('Example S01E00').kind,
        MediaKind.unclassified,
      );
      expect(normalizer.normalize('[HD]').title, '[HD]');
    });
  });

  group('Conservative metadata identity', () {
    MetadataCandidate movie(String id, {int? year = 2024}) => MetadataCandidate(
      provider: 'synthetic',
      id: id,
      title: 'Example',
      kind: MediaKind.movie,
      year: year,
    );

    test('matches a unique exact title, kind and year', () {
      final query = normalizer.normalize(
        'Example (2024)',
        kind: MediaKind.movie,
      );
      final match = matcher.match(query, [movie('1'), movie('2', year: 1990)]);
      expect(match.status, MetadataMatchStatus.matched);
      expect(match.candidate?.id, '1');
    });
    test(
      'title alone cannot silently associate a remake or regional channel',
      () {
        expect(
          matcher.match(
            normalizer.normalize('Example', kind: MediaKind.movie),
            [movie('1')],
          ).status,
          MetadataMatchStatus.ambiguous,
        );
        expect(
          matcher.match(normalizer.normalize('News', kind: MediaKind.live), [
            const MetadataCandidate(
              provider: 'synthetic',
              id: 'news',
              title: 'News',
              kind: MediaKind.live,
            ),
          ]).status,
          MetadataMatchStatus.ambiguous,
        );
      },
    );
    test(
      'same-year remakes remain ambiguous, duplicate provider ids do not',
      () {
        final query = normalizer.normalize(
          'Example (2024)',
          kind: MediaKind.movie,
        );
        expect(
          matcher.match(query, [movie('1'), movie('2')]).status,
          MetadataMatchStatus.ambiguous,
        );
        expect(
          matcher.match(query, [movie('1'), movie('1')]).status,
          MetadataMatchStatus.matched,
        );
      },
    );
    test('mismatched or missing year is never fused', () {
      final query = normalizer.normalize(
        'Example (2024)',
        kind: MediaKind.movie,
      );
      expect(
        matcher.match(query, [
          movie('1', year: 1990),
          movie('2', year: null),
        ]).status,
        MetadataMatchStatus.unmatched,
      );
    });
    test(
      'punctuation, accents and type differences are not silently erased',
      () {
        final query = normalizer.normalize(
          'Example! (2024)',
          kind: MediaKind.movie,
        );
        expect(
          matcher.match(query, [movie('1')]).status,
          MetadataMatchStatus.unmatched,
        );
        expect(
          matcher.match(normalizer.normalize('Example'), [movie('1')]).status,
          MetadataMatchStatus.unmatched,
        );
      },
    );
    test('episode identity needs coordinates and series year', () {
      const candidate = MetadataCandidate(
        provider: 'synthetic',
        id: 'ep1',
        title: 'Example',
        kind: MediaKind.episode,
        year: 2020,
        season: 2,
        episode: 3,
      );
      expect(
        matcher.match(normalizer.normalize('Example (2020) S02E03'), [
          candidate,
        ]).status,
        MetadataMatchStatus.matched,
      );
      expect(
        matcher.match(normalizer.normalize('Example (2020) S02E04'), [
          candidate,
        ]).status,
        MetadataMatchStatus.unmatched,
      );
      expect(
        matcher.match(normalizer.normalize('Example S02E03'), [
          candidate,
        ]).status,
        MetadataMatchStatus.ambiguous,
      );
    });
    test('series identity can match without episode coordinates', () {
      const candidate = MetadataCandidate(
        provider: 'synthetic',
        id: 'series-1',
        title: 'Example',
        kind: MediaKind.episode,
        year: 2020,
      );
      final match = matcher.match(
        normalizer.normalize('Example (2020)', kind: MediaKind.episode),
        [candidate],
      );
      expect(match.status, MetadataMatchStatus.matched);
      expect(match.candidate?.id, 'series-1');
    });
    test('series identity stays ambiguous without a year', () {
      const candidate = MetadataCandidate(
        provider: 'synthetic',
        id: 'series-1',
        title: 'Example',
        kind: MediaKind.episode,
        year: 2020,
      );
      expect(
        matcher.match(
          normalizer.normalize('Example', kind: MediaKind.episode),
          [candidate],
        ).status,
        MetadataMatchStatus.ambiguous,
      );
    });
    test('empty provider identity cannot be automatically linked', () {
      final query = normalizer.normalize(
        'Example (2024)',
        kind: MediaKind.movie,
      );
      expect(
        matcher.match(query, [movie('')]).status,
        MetadataMatchStatus.unmatched,
      );
    });
  });
}
