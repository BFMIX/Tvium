# Tvium product enhancement plan

Status: planning only, recorded 2026-10-28 from the user's product notes. No application behavior changes are authorized by this document alone. `docs/ROADMAP.md` remains the implementation status source of truth. Use Tvium's own designs, synthetic `.test` sources in tests, and sanitized aggregate diagnostics.

## Product rules

- Keep Tvium's approved three-card Home and its own design language. A floating navigation bar should preserve useful screen space without obscuring content.
- Store playlist and provider data locally unless a distinct user-approved service explicitly needs it. Never put provider credentials in AI requests, client logs, repository artifacts, or third-party analytics.
- Apply each feature to the platforms where it makes sense, with touch, keyboard, D-pad, and 720p/1080p checks. Keep low-memory Android TV catalog queries bounded and avoid eager in-memory expansion.
- Treat expiry as verified provider data only. M3U sources without expiry metadata should show source health and last refresh, never a guessed subscription deadline.

## Ordered implementation slices

| Order | Work item | Acceptance criteria | Dependencies and scope |
| --- | --- | --- | --- |
| 1 | Category and playlist manager | One page switches Live TV, Movies, and TV Shows; search matches country names/codes and group names; per-category show/hide, pin, rename, and parental lock; **Hide all** applies to the selected media kind; **Show matching** applies only to current filtered results; counts preview the affected set, changes persist per source/profile, and Undo is available. Hidden categories disappear from browsing and search without deleting source rows. | Build on existing Settings, profile/PIN policy, and paged database access. Preserve source metadata. Confirm how content in multiple sources is presented before coding. |
| 2 | Mobile catalog space | Floating bottom navigation respects safe areas, D-pad/keyboard focus where applicable, and screen-reader labels; film/series grids fit three posters on a standard phone portrait screen without oversized fixed headers; content remains scrollable behind the bar with enough bottom inset to reach the last row. | Mobile first; validate portrait and landscape with synthetic catalogs. Keep Home three cards. |
| 3 | Movie and series detail page | Tapping a title opens a full page; backdrop and poster use distinct media, with title, original title where useful, synopsis, year, language, cast/rating only when reliably available, episodes for series, playback and favorites. An uncertain TMDB match leaves original playlist data intact and visibly falls back. | Existing TMDB matching, artwork cache, accessibility, narrow and wide layouts. Avoid a modal over a modal. |
| 4 | Ready QR onboarding | On wide first-run screens, manual M3U/file/Xtream choices sit beside a ready QR pairing panel; on phones, the same paths stack without clipping. QR is short-lived, single-use, and contains no playlist secrets; approval and expiry states are clear. | Existing pairing flow and first-run design. Validate Web, TV, Mac, and narrow layouts. |
| 5 | Source status and notices | Settings show each source's type, safe aggregate counts, last successful refresh, refresh progress/error, and provider-reported expiration when available. Notify unobtrusively near verified expiry or meaningful refresh failure; allow dismissal and avoid repeated noise. | Existing source refresh schedule and Xtream account metadata. Do not infer expiry for M3U. |
| 6 | Guide coverage | Use provider EPG first; allow additional licensed/free guide feeds, conservative channel mapping with confidence and manual correction, Now/Next and a multi-day guide. Missing provider rows may use an explicitly configured external feed. Refresh, retention, time offset, and network policy are visible and testable. | Current XMLTV/SQLite EPG foundation. Verify source licenses, identifiers, time zones, and large-guide memory use before automatic fallback. |
| 7 | Player and viewing controls | Show current/next with progress and a guide below the live player; keep keyboard/remote navigation and fullscreen usable. Evaluate subtitles, catch-up/timeshift, reminders, casting, recording, and low-latency mode as separate platform slices. Never present unavailable guide or recording as working controls. | Stable playback and platform capability checks. Storage and rights review for timeshift/recording. |
| 8 | Integrations and AI | Improve TMDB reliability first. Evaluate app-managed server-side credentials for metadata and subtitles, then optional viewing-history sync and AI-assisted normalization/translation. Each service has explicit consent, quota, costs, license terms, secrets handling, and offline fallback. | Requires a service/privacy design decision; no provider or playlist secret is sent to an external model. |

## Verification for each slice

1. Add failing behavior tests with synthetic fixtures before changing code, then run focused tests and full workspace checks.
2. Verify the user-visible path on a small phone, a wide desktop, and a 720p/1080p TV layout. Record which physical devices were actually tested.
3. Test with a large synthetic catalog using bounded pages and measure startup, scrolling, memory, and import/refresh progress on a low-memory TV when available.
4. Update `docs/ROADMAP.md` with actual implementation and verification state. Do not mark a reference screenshot, code review, or successful build as a physical-device test.

## Open product decisions

- Whether category visibility and order are shared across devices or remain local to each profile and source.
- Which external EPG and subtitle sources have acceptable licensing, coverage, and cost for an app-managed service.
- Whether automatic guide fallback and AI-assisted normalization are opt-in, and what data leaves the device.
- Which player features are supported on Web, iOS, macOS, and low-memory Android TV rather than shown as universal controls.
