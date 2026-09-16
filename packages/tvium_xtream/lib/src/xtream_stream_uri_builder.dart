import 'package:tvium_core/tvium_core.dart';

import 'xtream_catalog.dart';
import 'xtream_credentials.dart';
import 'xtream_profile.dart';

abstract final class XtreamStreamUriBuilder {
  static final RegExp _safeExtension = RegExp(r'^[A-Za-z0-9]+$');

  static Uri build({
    required XtreamProfile profile,
    required XtreamCredentials credentials,
    required XtreamMediaItem item,
  }) {
    final (directory, fallbackExtension) = switch (item.kind) {
      MediaKind.live => ('live', 'ts'),
      MediaKind.movie => ('movie', 'mp4'),
      MediaKind.episode || MediaKind.unclassified => throw ArgumentError(
        'Series episodes require an episode stream identifier.',
      ),
    };
    final candidate = item.containerExtension?.trim() ?? '';
    final extension = _safeExtension.hasMatch(candidate)
        ? candidate.toLowerCase()
        : fallbackExtension;
    return profile.serverUri.replace(
      pathSegments: <String>[
        ...profile.serverUri.pathSegments.where(
          (segment) => segment.isNotEmpty,
        ),
        directory,
        credentials.username,
        credentials.password,
        '${item.id}.$extension',
      ],
      query: null,
    );
  }
}
