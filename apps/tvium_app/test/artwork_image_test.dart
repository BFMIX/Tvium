import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/artwork/artwork_image.dart';

void main() {
  test('artwork keys are stable and omit source details', () {
    final key = artworkCacheKey('source-1', 'movie-1', 'poster');
    expect(key, artworkCacheKey('source-1', 'movie-1', 'poster'));
    expect(key, isNot(contains('source-1')));
    expect(key, isNot(artworkCacheKey('source-1', 'movie-1', 'backdrop')));
  });
  test('a changed image URL cannot reuse the previous cached bytes', () {
    final first = artworkCacheKey(
      'source-1',
      'movie-1',
      'poster',
      uri: Uri.parse('https://art.example.test/first.jpg'),
    );
    final refreshed = artworkCacheKey(
      'source-1',
      'movie-1',
      'poster',
      uri: Uri.parse('https://art.example.test/second.jpg'),
    );
    expect(first, isNot(refreshed));
    expect(first, isNot(artworkCacheKey('source-1', 'movie-1', 'poster')));
    expect(first, isNot(contains('art.example.test')));
    expect(
      first,
      artworkCacheKey(
        'source-1',
        'movie-1',
        'poster',
        uri: Uri.parse('https://art.example.test/first.jpg'),
      ),
    );
  });
}
