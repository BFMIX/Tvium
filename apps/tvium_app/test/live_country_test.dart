import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/library/live_country.dart';

void main() {
  test('detects only explicit country prefixes', () {
    expect(countryForGroup('FR | News')?.code, 'FR');
    expect(countryForGroup('United Kingdom: Sports')?.code, 'GB');
    expect(countryForGroup('AFR | News'), isNull);
    expect(countryForGroup('Sports International'), isNull);
    expect(countryForGroup(null), isNull);
  });

  test('lists detected countries once and starts with France', () {
    final countries = countriesForGroups([
      'US | News',
      'FR | Cinema',
      'FR | Sports',
      'Europe | News',
    ]);
    expect(countries.map((country) => country.code), ['FR', 'US']);
  });
}
