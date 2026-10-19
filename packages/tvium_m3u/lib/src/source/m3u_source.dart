import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tvium_core/tvium_core.dart';

abstract interface class M3uSource {
  Stream<String> readLines();
}

final class M3uBytesSource implements M3uSource {
  const M3uBytesSource(this.bytes);

  final Uint8List bytes;

  @override
  Stream<String> readLines() {
    return Stream<List<int>>.value(bytes)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }
}

final class M3uSourceException implements Exception {
  const M3uSourceException(this.message);

  final String message;

  @override
  String toString() => 'M3uSourceException: $message';
}

final class M3uFileSource implements M3uSource {
  const M3uFileSource(this.path, {this.displayName, this.originalPath});

  final String path;
  final String? displayName;
  final String? originalPath;

  @override
  Stream<String> readLines() {
    return File(path)
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }
}

final class M3uUrlSource implements M3uSource {
  M3uUrlSource(
    this.uri, {
    this.client,
    this.timeout = const Duration(seconds: 20),
    this.maxBytes = 50 * 1024 * 1024,
  });

  final Uri uri;
  final Duration timeout;
  final int maxBytes;
  final http.Client? client;

  @override
  Stream<String> readLines() async* {
    final requestClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final request = http.Request('GET', uri);
      final response = await requestClient.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw M3uSourceException(
          SensitiveDataSanitizer.sanitize(
            'Playlist request failed (${response.statusCode}) for $uri',
          ),
        );
      }
      if (response.contentLength case final length? when length > maxBytes) {
        throw const M3uSourceException('Playlist exceeds the allowed size');
      }

      var receivedBytes = 0;
      final bytes = response.stream.map((chunk) {
        receivedBytes += chunk.length;
        if (receivedBytes > maxBytes) {
          throw const M3uSourceException('Playlist exceeds the allowed size');
        }
        return chunk;
      });
      yield* bytes.transform(utf8.decoder).transform(const LineSplitter());
    } on M3uSourceException {
      rethrow;
    } on TimeoutException {
      throw const M3uSourceException('Playlist request timed out');
    } on Object catch (error) {
      throw M3uSourceException(
        SensitiveDataSanitizer.sanitize('Playlist request failed: $error'),
      );
    } finally {
      if (ownsClient) {
        requestClient.close();
      }
    }
  }
}
