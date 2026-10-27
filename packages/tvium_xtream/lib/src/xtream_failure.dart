import 'xtream_catalog_step.dart';

enum XtreamFailure {
  incorrectCredentials,
  serverUnreachable,
  networkTimeout,
  unavailable,
  invalidResponse,
}

final class XtreamException implements Exception {
  const XtreamException(this.failure, {this.catalogStep});

  final XtreamFailure failure;
  final XtreamCatalogStep? catalogStep;

  String get message => switch (failure) {
    XtreamFailure.incorrectCredentials => 'Incorrect credentials',
    XtreamFailure.serverUnreachable => 'Server unreachable',
    XtreamFailure.networkTimeout => 'Network timeout',
    XtreamFailure.unavailable => 'Playlist unavailable',
    XtreamFailure.invalidResponse => 'Playlist format not supported',
  };

  @override
  String toString() => 'XtreamException: $message';
}
