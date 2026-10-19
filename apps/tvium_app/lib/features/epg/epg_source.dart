import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

typedef EpgStreamOpener = Stream<List<int>> Function(Uri uri);

abstract interface class EpgSource {
  String get sourceId;

  Stream<List<int>> readBytes();
}

final class EpgBytesSource implements EpgSource {
  EpgBytesSource({required this.sourceId, required List<int> bytes})
    : _bytes = List<int>.unmodifiable(bytes);

  factory EpgBytesSource.local(List<int> bytes) =>
      EpgBytesSource(sourceId: 'local-${sha256.convert(bytes)}', bytes: bytes);

  @override
  final String sourceId;
  final List<int> _bytes;

  @override
  Stream<List<int>> readBytes() => Stream<List<int>>.value(_bytes);

  @override
  String toString() => 'EpgBytesSource(<private>)';
}

final class EpgHttpsSource implements EpgSource {
  EpgHttpsSource(Uri uri, {EpgStreamOpener? opener})
    : _uri = _validate(uri),
      _opener = opener ?? _open {
    sourceId = 'https-${sha256.convert(utf8.encode(uri.toString()))}';
  }

  final Uri _uri;
  final EpgStreamOpener _opener;

  @override
  late final String sourceId;

  @override
  Stream<List<int>> readBytes() => _opener(_uri);

  static Uri _validate(Uri uri) {
    if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'An HTTPS URL is required.');
    }
    return uri;
  }

  static Stream<List<int>> _open(Uri uri) async* {
    final request = http.Request('GET', uri);
    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw const EpgSourceException();
    }
    yield* response.stream;
  }

  @override
  String toString() => 'EpgHttpsSource(<private>)';
}

final class EpgSourceException implements Exception {
  const EpgSourceException();

  @override
  String toString() => 'The programme guide could not be downloaded.';
}
