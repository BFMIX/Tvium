import 'package:tvium_core/tvium_core.dart';

final class MediaSource {
  const MediaSource({
    required this.uri,
    required this.title,
    this.headers = const <String, String>{},
  });

  final Uri uri;
  final String title;
  final Map<String, String> headers;

  @override
  String toString() {
    final safeUri = SensitiveDataSanitizer.sanitize(uri.toString());
    return 'MediaSource(title: $title, uri: $safeUri)';
  }
}
