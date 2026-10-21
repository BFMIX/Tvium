/// Country labels are derived only from explicit group prefixes. Unknown and
/// regional groups remain in the unfiltered library.
final class LiveCountry {
  const LiveCountry(this.code, this.name);

  final String code;
  final String name;

  String get flag =>
      String.fromCharCodes(code.codeUnits.map((unit) => 0x1F1E6 + unit - 0x41));
}

const _countryNames = <String, String>{
  'AE': 'United Arab Emirates',
  'AL': 'Albania',
  'AR': 'Argentina',
  'AT': 'Austria',
  'BE': 'Belgium',
  'BG': 'Bulgaria',
  'BH': 'Bahrain',
  'BR': 'Brazil',
  'CH': 'Switzerland',
  'CL': 'Chile',
  'CO': 'Colombia',
  'DE': 'Germany',
  'DK': 'Denmark',
  'DZ': 'Algeria',
  'EC': 'Ecuador',
  'EG': 'Egypt',
  'ES': 'Spain',
  'FI': 'Finland',
  'FR': 'France',
  'GB': 'United Kingdom',
  'GR': 'Greece',
  'HR': 'Croatia',
  'HU': 'Hungary',
  'IN': 'India',
  'IT': 'Italy',
  'JO': 'Jordan',
  'KW': 'Kuwait',
  'LB': 'Lebanon',
  'LY': 'Libya',
  'MA': 'Morocco',
  'MT': 'Malta',
  'MX': 'Mexico',
  'NL': 'Netherlands',
  'NO': 'Norway',
  'PK': 'Pakistan',
  'PL': 'Poland',
  'PS': 'Palestine',
  'PT': 'Portugal',
  'PY': 'Paraguay',
  'QA': 'Qatar',
  'RO': 'Romania',
  'RS': 'Serbia',
  'SA': 'Saudi Arabia',
  'SD': 'Sudan',
  'SE': 'Sweden',
  'SY': 'Syria',
  'TN': 'Tunisia',
  'TR': 'Turkey',
  'UA': 'Ukraine',
  'US': 'United States',
  'UY': 'Uruguay',
  'ZA': 'South Africa',
};

final _prefix = RegExp(r'^\s*([^|:–—-]+?)(?:\s*[|:–—-]\s*|$)');

LiveCountry? countryForGroup(String? group) {
  if (group == null) return null;
  final prefix = _prefix.firstMatch(group)?.group(1)?.trim();
  if (prefix == null || prefix.isEmpty) return null;
  final upper = prefix.toUpperCase();
  final code = switch (upper) {
    'UK' => 'GB',
    'USA' => 'US',
    'UAE' => 'AE',
    _ when _countryNames.containsKey(upper) => upper,
    _ =>
      _countryNames.entries
          .where((entry) => entry.value.toUpperCase() == upper)
          .map((entry) => entry.key)
          .firstOrNull,
  };
  final name = code == null ? null : _countryNames[code];
  return name == null ? null : LiveCountry(code!, name);
}

List<LiveCountry> countriesForGroups(Iterable<String?> groups) {
  final countries = <String, LiveCountry>{};
  for (final group in groups) {
    final country = countryForGroup(group);
    if (country != null) countries[country.code] = country;
  }
  final sorted = countries.values.toList(growable: false)
    ..sort((a, b) {
      if (a.code == 'FR') return -1;
      if (b.code == 'FR') return 1;
      return a.name.compareTo(b.name);
    });
  return sorted;
}

/// Approved local illustrations; the playlist alone decides which countries appear.
const countryArtwork = <String, String>{
  'FR': 'assets/countries/country-france.webp',
  'US': 'assets/countries/country-united-states.webp',
  'AL': 'assets/countries/country-albania.webp',
  'DZ': 'assets/countries/country-algeria.webp',
  'AR': 'assets/countries/country-argentina.webp',
  'AT': 'assets/countries/country-austria.webp',
  'BH': 'assets/countries/country-bahrain.webp',
  'BE': 'assets/countries/country-belgium.webp',
  'BR': 'assets/countries/country-brazil.webp',
  'BG': 'assets/countries/country-bulgaria.webp',
  'CL': 'assets/countries/country-chile.webp',
  'CO': 'assets/countries/country-colombia.webp',
  'HR': 'assets/countries/country-croatia.webp',
  'DK': 'assets/countries/country-denmark.webp',
  'EC': 'assets/countries/country-ecuador.webp',
  'EG': 'assets/countries/country-egypt.webp',
  'FI': 'assets/countries/country-finland.webp',
  'DE': 'assets/countries/country-germany.webp',
  'GR': 'assets/countries/country-greece.webp',
  'HU': 'assets/countries/country-hungary.webp',
  'IN': 'assets/countries/country-india.webp',
  'IT': 'assets/countries/country-italy.webp',
  'JO': 'assets/countries/country-jordan.webp',
  'KW': 'assets/countries/country-kuwait.webp',
  'LB': 'assets/countries/country-lebanon.webp',
  'LY': 'assets/countries/country-libya.webp',
  'MT': 'assets/countries/country-malta.webp',
  'MX': 'assets/countries/country-mexico.webp',
  'MA': 'assets/countries/country-morocco.webp',
  'NL': 'assets/countries/country-netherlands.webp',
  'NO': 'assets/countries/country-norway.webp',
  'PK': 'assets/countries/country-pakistan.webp',
  'PS': 'assets/countries/country-palestine.webp',
  'PY': 'assets/countries/country-paraguay.webp',
  'PL': 'assets/countries/country-poland.webp',
  'PT': 'assets/countries/country-portugal.webp',
  'QA': 'assets/countries/country-qatar.webp',
  'RO': 'assets/countries/country-romania.webp',
  'SA': 'assets/countries/country-saudi-arabia.webp',
  'RS': 'assets/countries/country-serbia.webp',
  'ZA': 'assets/countries/country-south-africa.webp',
  'ES': 'assets/countries/country-spain.webp',
  'SD': 'assets/countries/country-sudan.webp',
  'SE': 'assets/countries/country-sweden.webp',
  'CH': 'assets/countries/country-switzerland.webp',
  'SY': 'assets/countries/country-syria.webp',
  'TN': 'assets/countries/country-tunisia.webp',
  'TR': 'assets/countries/country-turkey.webp',
  'UA': 'assets/countries/country-ukraine.webp',
  'AE': 'assets/countries/country-united-arab-emirates.webp',
  'GB': 'assets/countries/country-united-kingdom.webp',
  'UY': 'assets/countries/country-uruguay.webp',
};
