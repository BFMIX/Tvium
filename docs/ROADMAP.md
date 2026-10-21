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
- Verified by widget tests: the three Home cards use fixed approved artwork, the carousel is spaced below them, and its provider poster is shown at a bounded size over a stable scenic backdrop.
- Verified by widget tests: the Home TV Shows card counts grouped series titles, matching the catalog rather than raw episode entries.
- Verified by synthetic tests: the carousel features playable titles with usable artwork first, and blank M3U logo attributes no longer create empty artwork references.
- Verified by widget tests: Home does not present an episode still as a series poster and includes each conventionally named local series only once in the carousel.
- Verified by widget tests: the Home carousel pauses behind an open title details dialog; its candidate list is reused between ticks until the catalog changes.
- Verified by widget tests: the carousel uses clean Movies/TV Shows labels instead of raw source category names while preserving the original metadata.
- Verified by widget tests: Live TV uses the approved scenic banner; Movies and TV Shows use a poster-left feature with real catalog artwork or a neutral fallback.
- Verified by widget tests: M3U episode stills are not promoted to series posters in the feature or poster grid.
- Verified by widget tests: title details place verified posters beside information and seasons on wide screens, stack on compact screens, and use neutral art for local series without a verified poster.
- Verified by widget tests: movie and series detail dialogs expose the existing opt-in online metadata view; live TMDB results still require a configured gateway and server-side token.
- Verified by synthetic tests: opted-in movie and series details start a local-gateway lookup on open, show provider descriptions and artwork inline, and label a single yearless series result as tentative. The gateway returns localized and original TMDB titles plus poster and backdrop references; the client still preserves playlist titles and rejects unsafe artwork URLs.
- Verified by synthetic tests: opted-in Home enriches only the displayed feature, uses a verified TMDB backdrop/poster, and stores verified public metadata under opaque keys for up to 30 days. A previously verified description remains available offline. Tentative matches and untrusted artwork addresses are never stored; consent is saved on the device.
- Verified by synthetic tests: Movies and TV Shows grids display cached verified TMDB posters with consent, including grouped series whose source image is an episode still. Grid scrolling reads the local cache without issuing a gateway request. Local matching accepts explicitly separated release years and common French accent variants while preserving ambiguous-result safeguards. Alternate regional titles beyond TMDB's localized and original names and live matching against the user's catalog still need validation without exporting playlist data.
- Verified by widget tests: a single tentative TMDB series result can be explicitly confirmed from its details, then its public poster and description remain verified after the details reopen. Unconfirmed tentative results do not enter the artwork cache.
- Verified by widget tests: compact Movies and TV Shows skip the feature panel so the poster grid is immediately available.
- Verified by widget tests: Settings has separate navigation entries for playlists, metadata, parental controls, programme guide, and about information.
- Highest current priority: apply the approved cinematic Home, Live TV, Movies, and TV Shows designs to the production Flutter screens.
- In progress: accessibility audits and full D-pad/remote runtime coverage.

## M4 — Live TV (in progress)

- Verified: grouped browsing and scoped search.
- Verified: safe XMLTV file/HTTPS import, deterministic channel matching, local EPG persistence, and honest Now/Next display.
- Verified: profile-scoped favorites and recently played history are persistent and exposed in the library UI.
- Verified by widget tests: wide Live TV keeps the channel stack visible beside the player preview while a channel plays.
- Verified by widget tests: the wide Live TV screen follows the approved four-zone layout with country, category, channel, and preview panels; narrower screens retain the country rail.
- Verified by widget tests: the country pane stays at left at 1280 px, uses approved local landmark illustrations for detected countries, and shows real or unavailable programme information below the player.
- Verified by widget tests: the wide country pane searches only detected countries; the adjacent category pane displays country-free labels while retaining original group values for filtering.
- Verified by widget tests: the wide channel pane includes its own search above the channel stack, scoped to the active country and category.
- Verified by widget tests: preview details remain tied to the playing channel when a different country is selected.
- Verified by widget tests: Live TV uses the scenic artwork as a page backdrop, local circular flags from the approved design, category icons, and a transparent country/category layout.
- Verified by widget tests: wide channel rows use a translucent glass surface, and compact country chips use the same local flag assets.
- Verified by widget tests: channel logos use contain sizing and show a fallback only when artwork is unavailable, avoiding overlapping logos.
- Verified by widget tests: the preview offers Play, Favorite, and an honest Now/Next guide; the player has a full screen view with play, channel, and volume controls.
- Verified by synthetic tests: Live TV derives a country rail from explicit group prefixes, starts with France when present, filters categories and channels by country, and keeps regional or ambiguous groups available through All countries.
- Verified by widget tests: the player zaps forward and backward through the current visible playable channel list, including wraparound.
- Verified by widget tests: focused Live TV playback responds to up/down remote keys for channel changes.
- Verified by widget tests: the Live TV player opens a searchable quick switcher scoped to visible playable channels; submitting a search selects the first match and leaves empty results open.
- In progress: physical remote validation, variant selection, and targeted health checks remain planned.

## M5 — Movies and TV Shows (in progress)

- Verified: Xtream series details load on demand and expose ordered seasons and playable episodes without persisting stream URLs.
- Verified: favorites and recently played history work across Live TV, Movies, and TV Shows.
- Verified by automated coverage: movie and episode playback surfaces, local progress checkpoints, automatic resume, and Continue Watching.
- Verified by widget tests: resumable movies appear above the movie poster catalog, keeping Home limited to destinations and carousel.
- Verified by widget tests: resumable local M3U episodes appear above the TV Shows catalog with artwork and playback progress.
- Verified by widget tests: Movies and TV Shows use horizontal category chips over the poster grid; short windows keep the header and Continue Watching compact enough for grid interaction.
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
- Verified by unit tests: due refresh checks are serialized per source; the application now checks once a minute while open and again on resume. Long-running device behavior still needs runtime validation.
- Verified by unit tests: a device clock rollback restarts the interval, and one source failure does not prevent other due sources from refreshing.
- Verified by widget tests: playlist settings show each source's last recorded refresh check time without exposing source connection details.
- Verified by automated tests: conventional M3U export URLs are conservatively recognized, then upgraded to Xtream only after successful authentication and catalog loading. Failed upgrades fall back to the original M3U import.
- Verified by synthetic tests: viewed logo, poster, and backdrop bytes use opaque disk-cache keys on native platforms; changing an image URL selects a different key, and saved verified metadata is bound to the source entry's original title and media kind so a replaced catalog row cannot inherit old artwork. Cache eviction and first-load offline behavior still need device validation.
- Planned: migration of previously saved M3U sources to Xtream after explicit source-identity reconciliation.
- Planned: credential reconnect and bulk organization.

## M7 — Parental controls (in progress)

Verified: durable profile-scoped parental-policy persistence, salted iterative PIN hashing, explicit category controls, protected-category filtering, locked-library search exclusion, and session unlock. Planned: poster blur and configurable timeout UX.

## M8 — Hardening (planned)

Performance, accessibility, security review, crash isolation, profiling, native player adapters, and real-device matrices.

## M9 — Release preparation (in progress)

Verified: reproducible macOS DMG, Android TV ARM64 APK, Web archive, Apple Swift Package Manager builds, TV launcher assets, and automated prerelease workflow. Planned: Store metadata using authorized demo content, final legal/privacy review, protected signing, notarization, and production release builds.

- Verified by synthetic tests: tagged builds can compare their version against published GitHub releases, skip drafts, retain stable-channel behavior, and notify the user of a newer release without sending library data.
- In progress: release builds embed the tag and monotonic build number. Automatic installation needs signed packages and platform-specific distribution before it can be enabled safely.
