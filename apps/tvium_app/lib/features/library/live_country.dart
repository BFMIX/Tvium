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
