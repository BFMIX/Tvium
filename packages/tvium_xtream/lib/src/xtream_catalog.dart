import 'package:tvium_core/tvium_core.dart';

final class XtreamCategory {
  const XtreamCategory({required this.id, required this.name});

  final String id;
  final String name;
}

final class XtreamMediaItem {
  const XtreamMediaItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.kind,
    required this.imageUri,
    required this.containerExtension,
    required this.epgChannelId,
  });

  final String id;
  final String name;
  final String? categoryId;
  final MediaKind kind;
  final Uri? imageUri;
  final String? containerExtension;
  final String? epgChannelId;
}

final class XtreamSeriesSummary {
  const XtreamSeriesSummary({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.coverUri,
  });

  final String id;
  final String name;
  final String? categoryId;
  final Uri? coverUri;
}

final class XtreamCatalog {
  XtreamCatalog({
    required Iterable<XtreamCategory> liveCategories,
    required Iterable<XtreamMediaItem> liveStreams,
    required Iterable<XtreamCategory> movieCategories,
    required Iterable<XtreamMediaItem> movies,
    required Iterable<XtreamCategory> seriesCategories,
    required Iterable<XtreamSeriesSummary> series,
    required Iterable<String> warnings,
  }) : liveCategories = List<XtreamCategory>.unmodifiable(liveCategories),
       liveStreams = List<XtreamMediaItem>.unmodifiable(liveStreams),
       movieCategories = List<XtreamCategory>.unmodifiable(movieCategories),
       movies = List<XtreamMediaItem>.unmodifiable(movies),
       seriesCategories = List<XtreamCategory>.unmodifiable(seriesCategories),
       series = List<XtreamSeriesSummary>.unmodifiable(series),
       warnings = List<String>.unmodifiable(warnings);

  final List<XtreamCategory> liveCategories;
  final List<XtreamMediaItem> liveStreams;
  final List<XtreamCategory> movieCategories;
  final List<XtreamMediaItem> movies;
  final List<XtreamCategory> seriesCategories;
  final List<XtreamSeriesSummary> series;
  final List<String> warnings;
}
