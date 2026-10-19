import '../media/media_kind.dart';
import 'playlist_title_normalizer.dart';

/// Attribution and cache information travels with external metadata.
final class MetadataProvenance {
  const MetadataProvenance({
    required this.provider,
    required this.fetchedAt,
    required this.expiresAt,
    required this.attribution,
    this.sourceUri,
  });

  final String provider;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  final String attribution;
  final Uri? sourceUri;
}

final class MetadataCandidate {
  const MetadataCandidate({
    required this.provider,
    required this.id,
    required this.title,
    required this.kind,
    this.year,
    this.season,
    this.episode,
    this.provenance,
  });

  final String provider;
  final String id;
  final String title;
  final MediaKind kind;
  final int? year;
  final int? season;
  final int? episode;
  final MetadataProvenance? provenance;
}

enum MetadataMatchStatus { matched, ambiguous, unmatched }

final class MetadataMatch {
  const MetadataMatch({
    required this.status,
    this.candidate,
    this.confidence = 0,
  });

  final MetadataMatchStatus status;
  final MetadataCandidate? candidate;

  /// A rule score, not a statistically calibrated probability.
  final double confidence;
}

/// Only high-confidence identities can be automatically associated.
/// A match supplies an overlay; it never mutates imported playlist data.
final class MetadataMatcher {
  const MetadataMatcher();

  MetadataMatch match(
    NormalizedPlaylistTitle query,
    Iterable<MetadataCandidate> candidates,
  ) {
    final ranked = <(MetadataCandidate, double)>[];
    final seen = <String>{};
    final title = _key(query.title);
    if (title.isEmpty || query.kind == MediaKind.unclassified) {
      return const MetadataMatch(status: MetadataMatchStatus.unmatched);
    }
    for (final candidate in candidates) {
      if (candidate.provider.trim().isEmpty || candidate.id.trim().isEmpty) {
        continue;
      }
      if (candidate.kind != query.kind || _key(candidate.title) != title) {
        continue;
      }
      if (query.year != null && candidate.year != query.year) continue;
      if (query.season != null && candidate.season != query.season) continue;
      if (query.episode != null && candidate.episode != query.episode) continue;
      if (query.kind == MediaKind.episode) {
        final queryHasCoordinates =
            query.season != null && query.episode != null;
        final candidateHasCoordinates =
            candidate.season != null && candidate.episode != null;
        final queryHasPartialCoordinates =
            (query.season == null) != (query.episode == null);
        final candidateHasPartialCoordinates =
            (candidate.season == null) != (candidate.episode == null);
        // Series rows have no episode coordinates; episode rows have both.
        // Never associate a series title with one specific episode.
        if (queryHasPartialCoordinates ||
            candidateHasPartialCoordinates ||
            queryHasCoordinates != candidateHasCoordinates) {
          continue;
        }
      }
      if (!seen.add('${candidate.provider}\u0000${candidate.id}')) continue;
      final score =
          0.90 +
          (query.year != null ? 0.05 : 0) +
          (query.episode != null ? 0.05 : 0);
      ranked.add((candidate, score));
    }
    ranked.sort((a, b) => b.$2.compareTo(a.$2));
    if (ranked.isEmpty) {
      return const MetadataMatch(status: MetadataMatchStatus.unmatched);
    }
    // A single search result is not proof of identity. Without the release
    // year, remakes remain possible; channels need a stable external channel
    // identifier or regional evidence that this title-only API does not have.
    if (query.kind == MediaKind.live ||
        query.year == null ||
        (ranked.length > 1 && ranked[0].$2 - ranked[1].$2 < 0.08)) {
      return MetadataMatch(
        status: MetadataMatchStatus.ambiguous,
        confidence: ranked[0].$2,
      );
    }
    return MetadataMatch(
      status: MetadataMatchStatus.matched,
      candidate: ranked.first.$1,
      confidence: ranked.first.$2,
    );
  }

  String _key(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
