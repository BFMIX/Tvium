# Tvium development handoff

Updated: 2026-11-04. Read `AGENTS.md` and `docs/ROADMAP.md` before changing code.

## Product and privacy

Tvium is a local-first Flutter IPTV player. Users bring their own M3U or Xtream source. Never copy a private playlist, provider address, credential, stream URL, or catalog row into tests, logs, documentation, screenshots, or AI prompts. Use synthetic `.test` fixtures and aggregate diagnostics. Keep repository content in English.

## Source of truth

- The active development checkout is `/Users/bfmix/Desktop/DEv/Project/Tvium Player` on `codex/tvium-priorities`. Inspect `git status`, `git log`, and remotes at the start of each session. Do not assume a worktree named `tvium-priorities` contains this branch; one similarly named checkout has held a different branch.
- `origin/main` and `codex/tvium-priorities` have diverged. Do not build from `main` or another checkout and describe it as the latest priority branch. Compare changes and integrate them with tests; a blind merge previously caused extensive analysis failures and was aborted.
- `origin/main` includes the Web M3U relay and onboarding changes through `f78d244`. GitHub Pages run `41914696751` succeeded on 2026-11-04. The separate Netlify relay was tested with synthetic URLs; the user's private Tesla playlist and playback have not been verified. The priority branch does not include all Web relay changes from `main`; integrate deliberately before a future Web release from this branch.
- `apps/tvium_app/android/app/src/main/AndroidManifest.xml` and `apps/tvium_app/pubspec.yaml` have pre-existing local edits for the Android renderer and alpha version. Preserve them until reviewed. The priority branch was pushed at `d5b7852` before the next implementation batch. The subsequent compact catalog, detail, player-control, source-entry, and documentation commits are local; inspect `git log` and `git status` for the exact current head. They have not been pushed or released.
- `dist/local-tests/Tvium-Android-TV-Universal-build16.apk` is the sole retained local APK. It targets both `armeabi-v7a` and `arm64-v8a`. Build numbers must increase when replacing the app on Android TV.

## Current verified behavior

- Android TV build 16 was installed and launched via ADB at the time of this note. `dumpsys package` reported `versionCode=16`. A local device screenshot showed centered onboarding content at the TV's 1920×1080 output (960×540 logical pixels at density 320). Confirm the installed `versionCode` after every TV installation; an APK build alone is not installation evidence.
- Large Xtream imports have separate catalog timeouts, progress reporting, and bounded partial recovery. Library startup uses bounded SQLite pages. Search tolerates punctuation and spelling variation across unloaded pages. These behaviors have automated coverage, but real low-memory TV import and playback still need measurement.
- Native artwork has a 256 MiB disk-cache budget, and Settings has a Storage page to inspect and clear downloaded images. The current branch passes full workspace formatting, analysis, tests, and a Flutter Web release build. The latest navigation safe-area adjustment also passed focused widget coverage and analysis.
- Compact navigation now floats above scrollable catalog content, with bottom scroll clearance and three movie posters per row at a 390 px viewport. Narrow landscape uses smaller posters and leaves scroll clearance under the floating navigation. Movie and local/Xtream series details open as full-page routes without nested dialogs in portrait and short landscape viewports, retain distinct backdrop/poster media, and expose a favorite toggle; larger screens keep dialogs. Source URLs are visible while passwords remain masked; Xtream derives its display name from the host. Full-screen VOD controls expose a seekbar, and Live TV controls place play/pause between previous and next.
- Category visibility persists by profile, source, and media kind. Settings exposes a manager with search, per-category visibility, Hide all, Show matching, affected counts, and Undo. Its compact tabs, text actions, and separated rows passed 390×844 and 960×540 widget layout tests; physical-device visual review remains open. Bulk changes run atomically and avoid one transaction per group. Native paging, counts, startup snapshots, and search exclude hidden groups inside the repository before applying page/search limits. Pinning, renaming, and per-category parental locks remain pending.
- SQLite schema version 7 adds a source/kind/position index for bounded catalog pages. Migration from version 6 and the query plan have synthetic tests; real low-memory device timing remains to be measured.
- Native onboarding now places compact manual source actions left of an always-visible QR panel on wide screens; narrow phones keep manual entry. A valid QR submission starts import without another confirmation. The source type remains visible during import; success is reported only after completion. The 960×540 layout, focus navigation, full workspace format, analysis, and tests pass. A release build was installed at `/Applications/Tvium.app` and launched on 2026-11-04. The current native changes have not yet been verified on a physical TV. Selecting an existing playlist in the installed phone app for QR sync is planned and not implemented.

## Next work

1. When the user reports a new TV issue, reproduce the exact logical viewport in a widget test and validate the resulting build on the physical TV when wireless debugging is available. Avoid exposing the user's library in screenshots or logs.
2. Reconcile the remaining `main` changes into the priority branch deliberately. In particular, review TV landscape navigation, macOS Keychain fallback, source refresh health, artwork storage, and CI/Pages changes. Some main features have already been ported; compare behavior and tests rather than replaying commits blindly.
3. Continue the active product plan (`docs/PRODUCT_ENHANCEMENT_PLAN.md`): verify mobile safe areas and layout on physical devices, enrich the full-page movie/series details, then implement category management. Casting/AirPlay requires native sender/receiver capability and stream handoff validation; do not add a decorative control before it works. Also continue low-memory profiling, native playback, QR pairing, and metadata matching checks.
4. Keep distribution separate from local testing. A push, GitHub release, web deployment, DMG, and APK publication require an explicit release request and successful release checks. Do not claim that a locally installed build is available to download.

## Efficient verification and device policy

Run focused tests first, then `dart run melos run format:check`, `dart run melos run analyze`, and `dart run melos run test` from the repo root. Serialize Flutter native builds. For Android TV use `flutter build apk --release --target-platform android-arm,android-arm64 --build-number N`; inspect the APK architecture and install with `adb install -r`, then read `dumpsys package` and launch state. Do not retain old local APKs after the new one is verified.

The user has asked to stop reinstalling the Mac and iPhone repeatedly when they already work. Install only when the change affects those platforms or the user requests it. Android TV installation requires the user to enable wireless debugging and request it; the current conversation includes that request. If ADB drops, continue independent work and report the unverified install state. Never install on another person's connected phone.
