# Metadata Enrichment

## Purpose

Tvium enriches playlist entries with clearer titles, artwork, summaries, years, and public channel references. Enrichment improves presentation only: the imported playlist remains the source of truth for identity and playback.

## Local-First Processing

Title cleanup, media classification, and candidate matching run on the device. The original playlist title is preserved, while derived fields remove common quality, language, season, and episode markers. Tvium accepts a match only when it is sufficiently specific and unambiguous; uncertain results leave the playlist data unchanged.

This local stage requires no account, network request, or API key.

## Optional Metadata Gateway

Remote enrichment is disabled by default and requires explicit user consent. When enabled, the app sends only:

- the cleaned title;
- the content kind (`movie`, `series`, or `live`);
- an optional year and interface language.

Tvium never sends playlist files, IPTV hostnames, source URLs, stream URLs, usernames, passwords, tokens, or private source identifiers to the gateway. The gateway returns bounded public candidates; final matching still happens locally.

Configure the app with a public HTTPS endpoint at build time:

```sh
flutter run --dart-define=TVIUM_METADATA_GATEWAY=https://metadata.example.com
```

Configure `TMDB_READ_ACCESS_TOKEN` only in the gateway environment. It must never be embedded in the app, committed to Git, or included in logs.

## Providers and Fallbacks

- **TMDB** is the primary movie and series source when its server-side token is configured.
- **TVmaze** is the series fallback when TMDB is unavailable or returns no result.
- **IPTV-org** supplies public channel identity data only; Tvium does not request its stream lists.

Search results are cached in memory for one hour. IPTV-org channel data is cached for 24 hours. Provider failures return a sanitized unavailable response and never prevent local playlist browsing or playback.

## Privacy, Attribution, and Operations

The gateway restricts request size, allowed values, upstream hosts, redirects, concurrency, and rate limits. It does not log request payloads or upstream error details. Production hosting must add TLS, abuse protection, and server-side secret management.

Product surfaces using enriched data must retain provider links and required attribution. In particular, display: “This product uses the TMDB API but is not endorsed or certified by TMDB.” TVmaze data requires CC BY-SA attribution, while IPTV-org database data is public domain; third-party artwork and trademarks may carry separate rights. Recheck every provider's current terms before commercial release.
