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
- Verified: macOS and Web builds plus real HLS playback using an authorized public stream.
- Verified: iOS 27 simulator build, install, launch, M3U URL import, and compact player-surface regression coverage. Post-correction iOS video playback remains to be re-run reliably.
- Verified: Android SDK/licensing setup, debug and profile APK builds, Android 16 phone launch, native file selection, a 12,808-entry local import, and compact onboarding regression coverage.
- Verified: Google TV ARM64 profile-build launch, 1080p adaptive layout, initial remote focus, and D-pad activation. The stock emulator has no usable local-document provider.
- In progress: Android public-HLS playback and a TV-friendly source-transfer path. Windows and tvOS runtime evidence remains outstanding.

## M2 — Library engine (in progress)

- In progress: versioned Drift/SQLite persistence with transactional playlist replacement, stable ordering, and migration coverage.
- Planned: normalization, variants, duplicate handling, series reconstruction, and indexed library search.

## M3 — UX foundation (planned)

Production design system, adaptive layouts, onboarding, home, accessibility, and D-pad/remote navigation.

## M4 — Live TV (planned)

Groups, search, favorites, EPG, zapping, quick switcher, variant selection, and targeted health checks.

## M5 — Movies and TV Shows (planned)

VOD details, seasons/episodes, progress, continue watching, history, and favorites.

## M6 — Playlist management (planned)

- In progress: credential-safe Xtream authentication and tolerant Live TV, VOD, and Series catalog mapping.
- Verified: deterministic added/changed/removed/unchanged diffing rejects ambiguous duplicate identities before replacing a stored playlist.
- Planned: secure platform storage, profile UI, multiple sources, durable user overlays, and bulk organization.

## M7 — Parental controls (planned)

Protected playlists/items/categories, hashed PIN, visibility modes, search exclusion, poster blur, and timeout.

## M8 — Hardening (planned)

Performance, accessibility, security review, crash isolation, profiling, native player adapters, and real-device matrices.

## M9 — Release preparation (planned)

Packaging, Store metadata using authorized demo content, final legal/privacy review, signing, and release builds.
