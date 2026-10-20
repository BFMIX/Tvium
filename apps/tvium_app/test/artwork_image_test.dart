import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/artwork/artwork_image.dart';

void main() {
  test('artwork keys are stable and omit source details', () {
    final key = artworkCacheKey('source-1', 'movie-1', 'poster');
    expect(key, artworkCacheKey('source-1', 'movie-1', 'poster'));
    expect(key, isNot(contains('source-1')));
    expect(key, isNot(artworkCacheKey('source-1', 'movie-1', 'backdrop')));
  });
}
