# Tvium EPG

Pure-Dart, offline XMLTV parsing and conservative channel matching. The package
does not fetch URLs, access provider accounts, or persist source credentials.

```dart
final result = await XmltvParser().parse(xmltvBytes);
final match = EpgChannelMatcher().match(
  const EpgChannelCandidate(
    appChannelId: 'app.test',
    tvgId: 'news.test',
    displayName: 'News HD',
  ),
  result.channels,
  explicitMappings: const {'app.test': 'news.test'},
);
```

## Import contract

- UTF-8 and XML events are decoded incrementally; records in the returned result
  and the current XML record remain in memory, not a complete XML document tree.
- XMLTV `start` and `stop` require `YYYYMMDDhhmmss`, optionally followed by a
  numeric `+hhmm` or `-hhmm` timezone. No offset means UTC. All output dates are UTC.
- Invalid programme records are skipped with fixed, sanitized warning strings.
  Missing channel IDs/display names are likewise skipped. Malformed XML, invalid
  UTF-8, any DOCTYPE, and custom/invalid entities fail with `FormatException`.
- Entity expansion is disabled in `XmlEventDecoder`. Only XML's five predefined
  entities and valid numeric character references are decoded separately.
- The first nonempty display name/title/subtitle/description is retained; all
  nonempty categories are retained. Public result lists and categories are copied
  into immutable lists. Icon URIs are metadata only and never fetched here.

## Matching contract

The matcher returns one `EpgChannelMatch` or `null`: exact `tvgId` first, then an
explicit mapping keyed by stable `appChannelId`, then a unique normalized name.
Normalization lowercases and removes punctuation/whitespace while retaining
Unicode letters/numbers, meaning-bearing plus signs, and quality markers (HD, SD,
4K). `News+` remains distinct from `News`. It does not use substring
or fuzzy matching, strip accents, or guess across ambiguous names. Duplicate exact
IDs are refused. A missing explicit mapping target fails closed, without a name
fallback.

## Verification

```sh
flutter test packages/tvium_epg/test
dart analyze packages/tvium_epg
```

All test inputs are synthetic, with `.test` identifiers and domains.
