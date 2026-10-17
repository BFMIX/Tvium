import 'package:test/test.dart';
import 'package:tvium_epg/tvium_epg.dart';

void main() {
  final matcher = EpgChannelMatcher();
  final channels = [
    EpgChannel(id: 'news.test', displayName: 'News HD'),
    EpgChannel(id: 'culture.test', displayName: 'Culture TV'),
  ];
  const candidate = EpgChannelCandidate(
    appChannelId: 'app.test',
    tvgId: 'news.test',
    displayName: 'Culture TV',
  );

  test('exact tvg ID wins over explicit mapping and display name', () {
    final match = matcher.match(
      candidate,
      channels,
      explicitMappings: {'app.test': 'culture.test'},
    );
    expect(match?.channelId, 'news.test');
    expect(match?.strategy, EpgMatchStrategy.exactId);
  });

  test('explicit mapping uses stable application channel ID', () {
    final match = matcher.match(
      const EpgChannelCandidate(
        appChannelId: 'app.test',
        displayName: 'News HD',
      ),
      channels,
      explicitMappings: {'app.test': 'culture.test'},
    );
    expect(match?.channelId, 'culture.test');
    expect(match?.strategy, EpgMatchStrategy.explicit);
  });

  test(
    'matches a unique normalized name without stripping quality suffixes',
    () {
      final match = matcher.match(
        const EpgChannelCandidate(
          appChannelId: 'app.test',
          displayName: '  NEWS - HD  ',
        ),
        channels,
      );
      expect(match?.channelId, 'news.test');
      expect(match?.strategy, EpgMatchStrategy.normalizedName);
    },
  );

  test('refuses ambiguous normalized names in either channel order', () {
    final ambiguous = [
      EpgChannel(id: 'news.a.test', displayName: 'News HD'),
      EpgChannel(id: 'news.b.test', displayName: 'NEWS-HD'),
    ];
    const input = EpgChannelCandidate(
      appChannelId: 'app.test',
      displayName: 'News HD',
    );
    expect(matcher.match(input, ambiguous), isNull);
    expect(matcher.match(input, ambiguous.reversed), isNull);
  });

  test(
    'does not guess when ID or explicit target is missing and name differs',
    () {
      expect(
        matcher.match(
          const EpgChannelCandidate(
            appChannelId: 'app.test',
            tvgId: 'missing.test',
            displayName: 'Unknown',
          ),
          channels,
          explicitMappings: {'app.test': 'missing.test'},
        ),
        isNull,
      );
    },
  );

  test(
    'does not normalize away accented or non-Latin names into emptiness',
    () {
      final match = matcher.match(
        const EpgChannelCandidate(appChannelId: 'app.test', displayName: '文化'),
        [EpgChannel(id: 'culture.test', displayName: '文化')],
      );
      expect(match?.channelId, 'culture.test');
    },
  );

  test('does not match blank names', () {
    expect(
      matcher.match(
        const EpgChannelCandidate(appChannelId: 'app.test', displayName: ' - '),
        [EpgChannel(id: 'blank.test', displayName: '')],
      ),
      isNull,
    );
  });

  test('does not confuse HD with SD or match substrings', () {
    expect(
      matcher.match(
        const EpgChannelCandidate(
          appChannelId: 'app.test',
          displayName: 'News',
        ),
        channels,
      ),
      isNull,
    );
  });

  test('does not collapse a plus channel into the base channel name', () {
    expect(
      matcher.match(
        const EpgChannelCandidate(
          appChannelId: 'app.test',
          displayName: 'News+',
        ),
        [EpgChannel(id: 'news.test', displayName: 'News')],
      ),
      isNull,
    );
    expect(
      matcher.match(
        const EpgChannelCandidate(
          appChannelId: 'app.test',
          displayName: 'News',
        ),
        [EpgChannel(id: 'news.plus.test', displayName: 'News+')],
      ),
      isNull,
    );
  });

  test('matches a plus channel independently of the base channel', () {
    final match = matcher.match(
      const EpgChannelCandidate(
        appChannelId: 'app.test',
        displayName: ' NEWS + ',
      ),
      [
        EpgChannel(id: 'news.test', displayName: 'News'),
        EpgChannel(id: 'news.plus.test', displayName: 'News+'),
      ],
    );
    expect(match?.channelId, 'news.plus.test');
    expect(match?.strategy, EpgMatchStrategy.normalizedName);
  });

  test('stale explicit mapping blocks an otherwise matching display name', () {
    expect(
      matcher.match(
        const EpgChannelCandidate(
          appChannelId: 'app.test',
          displayName: 'News HD',
        ),
        channels,
        explicitMappings: {'app.test': 'missing.test'},
      ),
      isNull,
    );
  });

  test('refuses duplicate exact IDs before mapping or name fallback', () {
    final duplicates = [
      EpgChannel(id: 'news.test', displayName: 'News HD'),
      EpgChannel(id: 'news.test', displayName: 'Other'),
      EpgChannel(id: 'culture.test', displayName: 'Culture TV'),
    ];
    expect(
      matcher.match(
        candidate,
        duplicates,
        explicitMappings: {'app.test': 'culture.test'},
      ),
      isNull,
    );
    expect(matcher.match(candidate, duplicates.reversed), isNull);
  });
}
