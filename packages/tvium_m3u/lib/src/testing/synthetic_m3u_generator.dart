/// Generates deterministic, fictional IPTV data for tests and benchmarks.
final class SyntheticM3uGenerator {
  const SyntheticM3uGenerator();

  Iterable<String> generateLines(int entryCount) sync* {
    if (entryCount < 0) {
      throw ArgumentError.value(entryCount, 'entryCount', 'must be positive');
    }
    yield '#EXTM3U';
    for (var index = 0; index < entryCount; index++) {
      final kind = index % 3;
      if (kind == 0) {
        yield '#EXTINF:-1 tvg-id="synthetic.$index" '
            'tvg-logo="https://images.example.test/channel/$index.png" '
            'group-title="Synthetic Live",Synthetic Channel $index HD';
        yield 'https://stream.example.test/live/$index/index.m3u8';
      } else if (kind == 1) {
        yield '#EXTINF:-1 '
            'tvg-logo="https://images.example.test/movie/$index.jpg" '
            'group-title="Synthetic Movies",Synthetic Movie $index (2025)';
        yield 'https://stream.example.test/vod/$index.mp4';
      } else {
        final season = (index % 12) + 1;
        final episode = (index % 24) + 1;
        final seasonLabel = season.toString().padLeft(2, '0');
        final episodeLabel = episode.toString().padLeft(2, '0');
        yield '#EXTINF:-1 group-title="Synthetic Series",'
            'Synthetic Show S${seasonLabel}E$episodeLabel';
        yield 'https://stream.example.test/series/$index.mkv';
      }
    }
  }
}
