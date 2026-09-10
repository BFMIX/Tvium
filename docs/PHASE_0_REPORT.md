# Phase 0 Report

**Completed:** 23 August 2026  
**Branch:** `feat/phase-0`

## Outcome

Phase 0 validates Tvium's Flutter/Dart workspace and a local-first vertical prototype. The application imports user-provided M3U URLs or files, parses entries progressively, groups Live, Movies, and TV Shows, renders safe logo fallbacks, supports keyboard focus, and opens selected media through an engine-neutral playback boundary. No content, account, analytics, advertising, payment, or Web proxy is included.

## Verified Environment

- Flutter 3.47.0 stable; Dart 3.13.0; Melos 7.8.2.
- macOS 27.0 prerelease on Apple Silicon through Rosetta.
- Xcode 27.0 beta and CocoaPods 1.17.0.
- Chrome installed; Xcode includes iOS 26.4 and iOS 27.0 simulator runtimes.
- Android SDK 36, Build Tools 36.0.0, Platform Tools, NDK 28.2, CMake 3.22.1, and the Android Emulator are installed; all SDK licenses are accepted.
- ARM64 Android 16 phone and Google TV emulator images are installed on the Apple Silicon host.

The current workspace passes `dart run melos run format:check`, strict analysis across six packages, and all 26 automated tests. `flutter build web --debug` produced `build/web`; macOS release, iOS 27 simulator debug, and Android debug/profile/release builds completed successfully. The ARM64 Android release APK is 60.3 MB and its merged manifest contains the production Internet permission. Native onboarding was visually inspected on macOS, iOS 27, Android 16 phone, and Google TV emulators.

Continuous integration retains the macOS build and entitlement audit and now adds Linux-hosted Android ARM64 release and Web release builds. These gates detect packaging regressions without distributing unsigned or development-signed binaries.

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

- Android debug and profile APK builds, installation, launch, local M3U selection, and a 12,808-entry import are verified on an Android 16 ARM64 phone emulator. A Google TV ARM64 emulator also launches the profile build at 1080p and accepts D-pad activation. Its stock image exposes no usable document provider for local M3U selection; public HLS decoding remains to be verified conclusively.
- iOS 27 build, installation, launch, and M3U URL import are verified. Playback after the compact-layout correction still requires a reliable simulator or physical-device run.
- Flutter does not officially support tvOS. A native Apple TV companion or an explicitly accepted third-party toolchain is required.
- Windows build/runtime behavior is unverified on this macOS host.
- Real network HLS decoding is verified with Apple's public Bip Bop stream on macOS and Chrome. Codec breadth, alternate tracks, subtitles, DRM, lifecycle recovery, and provider-specific streams remain unverified.
- Web playback remains subject to browser codec support, CORS, HTTPS/mixed-content rules, and provider headers. Tvium will not add a proxy to bypass these restrictions.
- Flutter reports that the current `media_kit` macOS plugins do not yet support Swift Package Manager; CocoaPods works now, but this becomes a future compatibility risk.
- Persistence, EPG, Xtream, source refresh/diffing, parental controls, and Store release work remain outside Phase 0.

## Post-Phase 0 Corrections

The macOS sandbox now grants outbound network access and read-only access to files explicitly selected by the user. A signed debug build passed an entitlement audit, and a manual import of the fictional `small.m3u` fixture opened the native file chooser and populated the library. Playlist URLs are concealed by default, credential-bearing errors remain sanitized, and file-picker failures now produce a localized safe message. CI builds the macOS app and audits these entitlements to prevent regressions.

An iOS 27 simulator build exposed a compact-layout defect: media selection invoked playback but no video surface was rendered below 900 logical pixels. The compact library now keeps a player surface above the media list, with a widget regression test. The build installs and launches on an iPhone 17 Pro simulator running iOS 27.0.

Android verification exposed a second compact-layout issue: source cards were arranged in a horizontally clipped row on phones. Widths below 600 logical pixels now use full-width stacked actions, while wider layouts retain the remote-friendly horizontal row. A widget regression test covers all three source actions, and the corrected screen was inspected in an Android profile build.

Google TV verification exposed an initial-focus issue. Wide layouts now focus the first source action automatically, so a remote user can open the URL flow with the centre button and move between sources with the D-pad. Local-file UX on TV still needs a product path that does not depend on a document provider being installed.

## Recommendation

Proceed to the next milestone after approving the platform playback and persistence architecture. Keep the engine-neutral playback and repository contracts, add conclusive Android/Google TV playback evidence, and validate each durable schema migration before enabling source refresh, Xtream, EPG, history, or parental controls.
