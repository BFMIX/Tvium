# Phase 0 Report

**Completed:** 23 August 2026  
**Branch:** `feat/phase-0`

## Outcome

Phase 0 validates Tvium's Flutter/Dart workspace and a local-first vertical prototype. The application imports user-provided M3U URLs or files, parses entries progressively, groups Live, Movies, and TV Shows, renders safe logo fallbacks, supports keyboard focus, and opens selected media through an engine-neutral playback boundary. No content, account, analytics, advertising, payment, or Web proxy is included.

## Verified Environment

- Flutter 3.47.0 stable; Dart 3.13.0; Melos 7.8.2.
- macOS 27.0 prerelease on Apple Silicon through Rosetta.
- Xcode 27.0 beta and CocoaPods 1.17.0.
- Chrome installed; Android SDK absent; iOS 27 simulator absent.

The final workspace passed `dart run melos run format:check`, strict analysis across six packages, and all 20 automated tests. `flutter build web --debug` produced `build/web`; `flutter build macos --debug` produced `Tvium.app`. The native onboarding window was launched and visually inspected in French at 800 × 632.

## Parser Measurements

Each command used `dart run benchmark/parser_benchmark.dart --entries N` in a fresh Dart process. Results are observations from this machine, not performance guarantees.

| Entries | Elapsed | Entries/s | Observed RSS delta |
|---:|---:|---:|---:|
| 1,000 | 81,982 µs | 12,198 | 2,703,360 B |
| 10,000 | 248,817 µs | 40,190 | 3,641,344 B |
| 50,000 | 653,396 µs | 76,523 | 16,175,104 B |
| 100,000 | 1,153,912 µs | 86,662 | 15,216,640 B |

All generated entries were parsed with zero warnings. Separate JIT starts, allocator behavior, and sampling make the RSS figures non-monotonic. The parser streams lines and emits bounded batches; the UI uses lazy lists rather than constructing the full library view at once.

## Architecture Evidence

- `tvium_core` owns media kinds and diagnostic sanitization.
- `tvium_m3u` provides file, URL, and in-memory byte sources plus source-preserving progressive parsing.
- `tvium_database` exposes a repository contract and tested in-memory Phase 0 adapter; Drift/SQLite remains planned.
- `tvium_playback` isolates `media_kit` behind `PlaybackEngine` and sanitizes failure/debug output.
- Riverpod composes import state; localized adaptive widgets consume package APIs.

Flutter and Melos were selected for shared multi-platform code and explicit package boundaries. `media_kit` is provisional evidence only, not a final native-player decision.

## Security and Privacy

Fixtures use reserved `.test` hosts. Tests verify removal of credentials, URL paths, and query values from diagnostics. Indexed media projections store opaque source references instead of credentials or full sensitive URLs. Tvium sends no telemetry and includes no server-side relay.

## Limits and Risks

- Android builds and runtime behavior are blocked locally by the missing Android SDK.
- iOS/tvOS runtime behavior is unverified; the iOS 27 simulator is not installed. tvOS is a product target, not a generated Phase 0 runner.
- Windows build/runtime behavior is unverified on this macOS host.
- The HLS adapter, lifecycle contract, Web build, and macOS integration compile are verified; actual network decoding, codecs, tracks, subtitles, DRM, and recovery were not exercised with a stream in the final run.
- Web playback remains subject to browser codec support, CORS, HTTPS/mixed-content rules, and provider headers. Tvium will not add a proxy to bypass these restrictions.
- Flutter reports that the current `media_kit` macOS plugins do not yet support Swift Package Manager; CocoaPods works now, but this becomes a future compatibility risk.
- Persistence, EPG, Xtream, source refresh/diffing, parental controls, and Store release work remain outside Phase 0.

## Post-Phase 0 Corrections

The macOS sandbox now grants outbound network access and read-only access to files explicitly selected by the user. A signed debug build passed an entitlement audit, and a manual import of the fictional `small.m3u` fixture opened the native file chooser and populated the library. Playlist URLs are concealed by default, credential-bearing errors remain sanitized, and file-picker failures now produce a localized safe message. CI builds the macOS app and audits these entitlements to prevent regressions.

## Recommendation

Proceed to the next milestone only after installing the Android SDK and adding real-device playback spikes using explicitly authorized test streams. Keep the playback and repository abstractions until platform evidence justifies native adapter choices and a durable schema.
