enum XtreamCatalogStep {
  liveCategories('get_live_categories'),
  liveStreams('get_live_streams'),
  vodCategories('get_vod_categories'),
  vodStreams('get_vod_streams'),
  seriesCategories('get_series_categories'),
  series('get_series');

  const XtreamCatalogStep(this.action);

  final String action;
}

typedef XtreamCatalogProgress = void Function(
  XtreamCatalogStep step,
  int current,
  int total,
);
