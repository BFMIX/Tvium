# Roadmap

Status values are `planned`, `in progress`, `verified`, or `blocked`. A milestone becomes verified only from test/build/runtime evidence.

## M0 — Foundations (verified)

- Flutter workspace, strict lint, CI, modular packages.
- Product, architecture, data, security, UX, testing, legal, and ADR documents.
- Phase 0 report and reproducible verification commands.

## M1 — Technical prototype (in progress)

- Verified: progressive M3U file/URL import, grouping, lazy lists, and logo fallbacks.
- Verified: playback abstraction, state contract, and provisional `media_kit` integration builds.
- Verified: deterministic synthetic playlists plus timing and RSS observations through 100,000 entries.
- Verified: macOS and Web debug builds. Network HLS playback remains unverified; Android is blocked locally until its SDK exists.

## M2 — Library engine (planned)

Normalization, classification, variants, duplicates, series reconstruction, SQLite indexing, and indexed search.

## M3 — UX foundation (planned)

Production design system, adaptive layouts, onboarding, home, accessibility, and D-pad/remote navigation.

## M4 — Live TV (planned)

Groups, search, favorites, EPG, zapping, quick switcher, variant selection, and targeted health checks.

## M5 — Movies and TV Shows (planned)

VOD details, seasons/episodes, progress, continue watching, history, and favorites.

## M6 — Playlist management (planned)

Multiple sources, refresh, incremental diff, durable user overlays, bulk organization, and Xtream integration.

## M7 — Parental controls (planned)

Protected playlists/items/categories, hashed PIN, visibility modes, search exclusion, poster blur, and timeout.

## M8 — Hardening (planned)

Performance, accessibility, security review, crash isolation, profiling, native player adapters, and real-device matrices.

## M9 — Release preparation (planned)

Packaging, Store metadata using authorized demo content, final legal/privacy review, signing, and release builds.
