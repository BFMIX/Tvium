import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/home/catalog_search.dart';

void main() {
  test('matches punctuation, accents, and small spelling mistakes', () {
    expect(catalogTitleMatches('Spider-Man', 'Spider man'), isTrue);
    expect(catalogTitleMatches('Spider-Man', 'Spidr man'), isTrue);
    expect(catalogTitleMatches('L’Été dernier', 'ete dernier'), isTrue);
    expect(catalogTitleMatches('Spider-Man', 'Batman'), isFalse);
  });
}
