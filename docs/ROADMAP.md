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

- Verified: versioned Drift/SQLite persistence with transactional catalog replacement, stable ordering, and migration coverage.
- Verified: conservative local title normalization and metadata matching preserve the original playlist data.
- Verified: the optional metadata gateway accepts cleaned identity fields only, with TMDB, TVmaze, and IPTV-org adapters behind a strict privacy boundary.
- In progress: variants, episode persistence, and indexed library search. Tolerant Xtream season/episode retrieval is verified at the adapter boundary.

## M3 — UX foundation (in progress)

- Verified: approved Tvium logo family, application icons, visual reference screens, and brand color tokens are organized and integrated into the prototype.
- Verified: production color and typography foundations, adaptive four-destination navigation shell, onboarding, Home, compact touch navigation, and wide-screen focus states.
- Verified: the production Home screen includes a cinematic, five-second controllable feature carousel with adjacent Play and View details actions.
- Verified by widget tests: Home shows exactly three destination cards before the carousel, with no extra history rail.
- Verified by widget tests: Settings has separate navigation entries for playlists, metadata, parental controls, programme guide, and about information.
- Highest current priority: apply the approved cinematic Home, Live TV, Movies, and TV Shows designs to the production Flutter screens.
- In progress: accessibility audits and full D-pad/remote runtime coverage.

## M4 — Live TV (in progress)

- Verified: grouped browsing and scoped search.
- Verified: safe XMLTV file/HTTPS import, deterministic channel matching, local EPG persistence, and honest Now/Next display.
- Verified: profile-scoped favorites and recently played history are persistent and exposed in the library UI.
- Verified by widget tests: wide Live TV keeps the channel stack visible beside the player preview while a channel plays.
- In progress: zapping, quick switcher, variant selection, and targeted health checks remain planned.

## M5 — Movies and TV Shows (in progress)

- Verified: Xtream series details load on demand and expose ordered seasons and playable episodes without persisting stream URLs.
- Verified: favorites and recently played history work across Live TV, Movies, and TV Shows.
- Verified by automated coverage: movie and episode playback surfaces, local progress checkpoints, automatic resume, and Continue Watching.
- Verified by widget tests: resumable movies appear above the movie poster catalog, keeping Home limited to destinations and carousel.
- Verified by automated coverage: M3U episode titles using common provider conventions are grouped locally into series, seasons, and episodes; native Xtream series structure remains authoritative when available.
- In progress: physical-device playback validation. Enriched VOD details and durable episode catalogs remain planned.

## M6 — Playlist management (planned)

- Verified: credential-safe Xtream authentication, tolerant Live TV/VOD/Series catalog mapping, direct library transition after sign-in, and secure on-demand stream URL resolution for playable Live TV and VOD items.
- Verified: deterministic added/changed/removed/unchanged diffing rejects ambiguous duplicate identities before replacing a stored playlist.
- Verified: connected Xtream sources can be refreshed from Settings with aggregate change counts; failed refreshes keep the last working catalog.
- Verified: native profile persistence, active-catalog restoration, compact profile switching, and shared Xtream sources without duplicate catalogs.
- Verified: tolerant Series season/episode retrieval plus durable profile-scoped favorite, history, and parental-policy repositories.
- Verified: on-demand Xtream episode catalog and playback integration plus profile-scoped overlay UX.
- Verified: per-source rename, refresh, and profile-aware removal controls.
- Verified by automated tests: cached library startup remains usable while each source follows its own configurable refresh interval; failed refreshes retain cached entries.
- Verified by automated tests: conventional M3U export URLs are conservatively recognized, then upgraded to Xtream only after successful authentication and catalog loading. Failed upgrades fall back to the original M3U import.
- In progress: viewed logo, poster, and backdrop bytes use an opaque-key disk cache on native platforms; cache eviction and first-load offline behavior need device validation.
- Planned: migration of previously saved M3U sources to Xtream after explicit source-identity reconciliation.
- Planned: credential reconnect and bulk organization.

## M7 — Parental controls (in progress)

Verified: durable profile-scoped parental-policy persistence, salted iterative PIN hashing, explicit category controls, protected-category filtering, locked-library search exclusion, and session unlock. Planned: poster blur and configurable timeout UX.

## M8 — Hardening (planned)

Performance, accessibility, security review, crash isolation, profiling, native player adapters, and real-device matrices.

## M9 — Release preparation (in progress)

Verified: reproducible macOS DMG, Android TV ARM64 APK, Web archive, Apple Swift Package Manager builds, TV launcher assets, and automated prerelease workflow. Planned: Store metadata using authorized demo content, final legal/privacy review, protected signing, notarization, and production release builds.
