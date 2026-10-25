# Approved requirements plan

This plan translates [Product Definition](../PRODUCT.md), [Scope](../SCOPE.md), and the evidence in [Roadmap](../ROADMAP.md) into delivery order. “Verified” here means covered by the cited workspace tests or builds, not necessarily tested on every physical device. An item stays open until its acceptance check passes.

| Priority | Approved capability | Current state | Acceptance check |
|---|---|---|---|
| P0 | Reliable first launch and source import: clear English/French localization, cinematic onboarding, M3U URL/file, Xtream, QR phone pairing, progress, safe errors. | Implemented with synthetic/widget coverage; QR and large imports still need clean-device checks. | Fresh macOS, Android TV, and Web sessions finish an authorized synthetic import without repeated prompts or an indefinite spinner. |
| P0 | Trustworthy releases and updates: matching signed APKs, current DMG/APK/Web assets, update notices, protected CI, macOS signing and notarization. | Alpha.8 passed all release jobs and the downloaded APK matched the expected release certificate. macOS distribution and automatic installation remain open. | A release run passes every job, each asset version/signature is checked, and an installed app can update without losing local data. |
| P1 | Local library and source lifecycle: cached startup, per-source refresh schedule, safe diff/rollback, M3U-to-Xtream upgrade, artwork persistence, profiles, favorites, history, parental policies. | Most paths have synthetic tests; long-running refresh, migration, cache eviction, and device persistence need validation. | Large catalogs remain usable during refresh; failure preserves prior data; restart restores artwork and profile state. |
| P1 | TV-first Live TV: country and category rails, channel list, consistent logos, player controls, searchable switching, full screen, XMLTV Now/Next. | Layout and player behavior have widget tests; real remote and broader stream playback still need evidence. | D-pad can complete browsing and playback on a physical TV; controls clear in full screen; guide shows real data or an honest unavailable state. |
| P2 | Movies and series: poster grids, resumable playback, seasons/episodes, localized TMDB matching, descriptions and backdrops, compact layouts. | Catalog and selective enrichment paths are tested; live public gateway and physical playback remain open. | A clean install with the hosted gateway displays verified metadata automatically when enabled; ambiguous matches do not overwrite source data. |
| P2 | Cross-platform hardening: accessibility, performance at 10,000–100,000 entries, crash recovery, Windows/iOS/Android/TV matrices, privacy and Store readiness. | Foundations and synthetic benchmarks exist; the full device and distribution matrix is incomplete. | Each advertised platform passes its own build, install, navigation, playback, privacy, and update checklist. |

## Delivery sequence

1. Resolve release signing and the clean-install import path before asking users to retest new features.
2. Validate cached source lifecycle and artwork on real devices, then complete Live TV remote and playback checks.
3. Host the metadata gateway and verify Movies/TV Shows enrichment with permitted public test titles.
4. Split large UI modules in small tested slices while completing accessibility and performance checks.
5. Promote platform availability only after its release and device checklist passes.

V1 continues to exclude bundled providers, accounts, cloud sync, advertising, payment, recording, stream downloads, AI recommendations, Web proxying, advanced casting, and voice search. See [Scope](../SCOPE.md) for the full exclusion list.
