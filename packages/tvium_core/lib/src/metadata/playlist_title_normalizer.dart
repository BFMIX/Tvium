import '../media/media_kind.dart';

/// A derived title. The imported title is always retained unchanged.
final class NormalizedPlaylistTitle {
  const NormalizedPlaylistTitle({
    required this.originalTitle,
    required this.title,
    required this.kind,
    this.year,
    this.season,
    this.episode,
    this.language,
    this.quality,
    this.warnings = const [],
  });

  final String originalTitle;
  final String title;
  final MediaKind kind;
  final int? year;
  final int? season;
  final int? episode;
  final String? language;
  final String? quality;
  final List<String> warnings;
}

/// Conservative rules intended for local use before any optional API lookup.
final class PlaylistTitleNormalizer {
  const PlaylistTitleNormalizer();

  NormalizedPlaylistTitle normalize(
    String originalTitle, {
    MediaKind kind = MediaKind.unclassified,
  }) {
    var title = originalTitle.trim().replaceAll(RegExp(r'\s+'), ' ');
    String? language;
    String? quality;
    var languageConflict = false;
    var qualityConflict = false;
    final warnings = <String>[];
    const languages = {'FR', 'EN', 'ES', 'DE', 'IT', 'PT', 'AR'};
    const qualities = {
      'SD',
      'HD',
      'FHD',
      'UHD',
      '4K',
      '8K',
      '720P',
      '1080P',
      '2160P',
    };
    // Only explicitly delimited edge tags qualify. Bare title words remain.
    final leading = RegExp(r'^\[([A-Za-z0-9]+)\]\s*');
    final trailing = RegExp(
      r'\s*(?:\[([A-Za-z0-9]+)\]|\(([A-Za-z0-9]+)\)|[|•]\s*([A-Za-z0-9]+))$',
    );
    bool consume(String token) {
      final upper = token.toUpperCase();
      if (languages.contains(upper)) {
        if (language != null && language != upper.toLowerCase()) {
          warnings.add('Conflicting language tags');
          languageConflict = true;
        }
        language ??= upper.toLowerCase();
        return true;
      }
      if (qualities.contains(upper)) {
        if (quality != null && quality != upper) {
          warnings.add('Conflicting quality tags');
          qualityConflict = true;
        }
        quality ??= upper;
        return true;
      }
      return false;
    }

    for (var pass = 0; pass < 12; pass++) {
      final start = leading.firstMatch(title);
      if (start != null && start.end < title.length && consume(start[1]!)) {
        title = title.substring(start.end).trim();
        continue;
      }
      final end = trailing.firstMatch(title);
      if (end != null &&
          end.start > 0 &&
          consume(end[1] ?? end[2] ?? end[3]!)) {
        title = title.substring(0, end.start).trim();
        continue;
      }
      break;
    }

    int? season;
    int? episode;
    if (kind != MediaKind.live && kind != MediaKind.movie) {
      final serialPatterns = <RegExp>[
        RegExp(
          r'(?:\s*[-–—:]\s*|\s+)[Ss](\d{1,2})\s*[Ee](\d{1,3})'
          r'(?:\s*[-–—:].*)?$',
        ),
        RegExp(
          r'(?:\s*[-–—:]\s*|\s+)(\d{1,2})\s*x\s*(\d{1,3})'
          r'(?:\s*[-–—:].*)?$',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:\s*[-–—:]\s*|\s+)(?:Season|Saison|Temporada)\s+(\d{1,2})'
          r'\s+(?:Episode|Épisode|Episodio)\s+(\d{1,3})'
          r'(?:\s*[-–—:].*)?$',
          caseSensitive: false,
        ),
      ];
      RegExpMatch? serial;
      for (final pattern in serialPatterns) {
        serial = pattern.firstMatch(title);
        if (serial != null) break;
      }
      if (serial != null && int.parse(serial[2]!) > 0) {
        season = int.parse(serial[1]!);
        episode = int.parse(serial[2]!);
        title = title
            .substring(0, serial.start)
            .replaceFirst(RegExp(r'\s*[-–—:]\s*$'), '')
            .trim();
        kind = MediaKind.episode;
      }
    }
    int? year;
    if (kind != MediaKind.live) {
      final date = RegExp(
        r'(?:\s+\((\d{4})\)|\s+\[(\d{4})\]|\s+[-–—]\s+(\d{4}))$',
      ).firstMatch(title);
      if (date != null) {
        final parsed = int.parse(date[1] ?? date[2] ?? date[3]!);
        if (parsed >= 1888 && parsed <= 2100) {
          year = parsed;
          title = title.substring(0, date.start).trim();
        }
      }
    }
    return NormalizedPlaylistTitle(
      originalTitle: originalTitle,
      title: title,
      kind: kind,
      year: year,
      season: season,
      episode: episode,
      language: languageConflict ? null : language,
      quality: qualityConflict ? null : quality,
      warnings: List.unmodifiable(warnings),
    );
  }
}
