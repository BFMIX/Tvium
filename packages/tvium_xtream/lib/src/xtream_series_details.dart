final class XtreamSeriesDetails {
  XtreamSeriesDetails({
    required this.id,
    required this.name,
    required this.coverUri,
    required Iterable<Uri> backdropUris,
    required this.plot,
    required this.cast,
    required this.director,
    required this.genre,
    required this.releasedAt,
    required this.rating,
    required Iterable<XtreamSeason> seasons,
    required Iterable<String> warnings,
  }) : backdropUris = List<Uri>.unmodifiable(backdropUris),
       seasons = List<XtreamSeason>.unmodifiable(seasons),
       warnings = List<String>.unmodifiable(warnings);

  final String id;
  final String name;
  final Uri? coverUri;
  final List<Uri> backdropUris;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final DateTime? releasedAt;
  final double? rating;
  final List<XtreamSeason> seasons;
  final List<String> warnings;
}

final class XtreamSeason {
  XtreamSeason({
    required this.id,
    required this.number,
    required this.name,
    required this.overview,
    required this.coverUri,
    required Iterable<XtreamEpisode> episodes,
  }) : episodes = List<XtreamEpisode>.unmodifiable(episodes);

  final String? id;
  final int number;
  final String name;
  final String? overview;
  final Uri? coverUri;
  final List<XtreamEpisode> episodes;
}

final class XtreamEpisode {
  const XtreamEpisode({
    required this.id,
    required this.seasonNumber,
    required this.number,
    required this.title,
    required this.containerExtension,
    required this.imageUri,
    required this.plot,
    required this.releasedAt,
    required this.rating,
    required this.duration,
  });

  final String id;
  final int seasonNumber;
  final int number;
  final String title;
  final String? containerExtension;
  final Uri? imageUri;
  final String? plot;
  final DateTime? releasedAt;
  final double? rating;
  final Duration? duration;
}
