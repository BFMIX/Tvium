/// Compares display titles without requiring identical punctuation or accents.
String normalizeCatalogSearch(String value) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };
  final lowered = value
      .toLowerCase()
      .split('')
      .map((character) => accents[character] ?? character)
      .join();
  return lowered
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool catalogTitleMatches(String title, String query) {
  final name = normalizeCatalogSearch(title);
  final needle = normalizeCatalogSearch(query);
  if (needle.isEmpty) return true;
  if (name.contains(needle) ||
      name.replaceAll(' ', '').contains(needle.replaceAll(' ', ''))) {
    return true;
  }
  final words = name.split(' ');
  return needle
      .split(' ')
      .every(
        (token) => words.any((word) {
          if (word.startsWith(token) || token.startsWith(word)) {
            return true;
          }
          if (token.length < 4 || (word.length - token.length).abs() > 2) {
            return false;
          }
          return _editDistanceAtMostTwo(word, token);
        }),
      );
}

bool _editDistanceAtMostTwo(String left, String right) {
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var row = 1; row <= left.length; row++) {
    final current = List<int>.filled(right.length + 1, 0)..[0] = row;
    var best = current[0];
    for (var column = 1; column <= right.length; column++) {
      current[column] = [
        previous[column] + 1,
        current[column - 1] + 1,
        previous[column - 1] + (left[row - 1] == right[column - 1] ? 0 : 1),
      ].reduce((a, b) => a < b ? a : b);
      if (current[column] < best) best = current[column];
    }
    if (best > 2) return false;
    previous = current;
  }
  return previous.last <= 2;
}
