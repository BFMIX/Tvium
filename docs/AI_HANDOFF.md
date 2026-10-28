# Tvium development handoff

Updated: 2026-10-28. Read `AGENTS.md` and `docs/ROADMAP.md` before changing code.

## Product and privacy

Tvium is a local-first Flutter IPTV player. Users bring their own M3U or Xtream source. Never copy a private playlist, provider address, credential, stream URL, or catalog row into tests, logs, documentation, screenshots, or AI prompts. Use synthetic `.test` fixtures and aggregate diagnostics. Keep repository content in English.

## Source of truth

- The active development checkout is `/Users/bfmix/Desktop/DEv/Project/Tvium Player` on `codex/tvium-priorities`. Inspect `git status`, `git log`, and remotes at the start of each session. Do not assume a worktree named `tvium-priorities` contains this branch; one similarly named checkout has held a different branch.
- `origin/main` and `codex/tvium-priorities` have diverged. Do not build from `main` or another checkout and describe it as the latest priority branch. Compare changes and integrate them with tests; a blind merge previously caused extensive analysis failures and was aborted.
- `apps/tvium_app/android/app/src/main/AndroidManifest.xml` and `apps/tvium_app/pubspec.yaml` have pre-existing local edits for the Android renderer and alpha version. Preserve them until reviewed. The latest local commits on the priority branch are the TV onboarding layout, bounded artwork cache, and storage settings. No push or release has been made from those commits.
- `dist/local-tests/Tvium-Android-TV-Universal-build16.apk` is the sole retained local APK. It targets both `armeabi-v7a` and `arm64-v8a`. Build numbers must increase when replacing the app on Android TV.

## Current verified behavior

- Android TV build 16 was installed and launched via ADB at the time of this note. `dumpsys package` reported `versionCode=16`. A local device screenshot showed centered onboarding content at the TV's 1920×1080 output (960×540 logical pixels at density 320). Confirm the installed `versionCode` after every TV installation; an APK build alone is not installation evidence.
- Large Xtream imports have separate catalog timeouts, progress reporting, and bounded partial recovery. Library startup uses bounded SQLite pages. Search tolerates punctuation and spelling variation across unloaded pages. These behaviors have automated coverage, but real low-memory TV import and playback still need measurement.
- Native artwork now has a 256 MiB disk-cache budget, and Settings has a Storage page to inspect and clear downloaded images. The latest workspace format, analysis, and test commands passed before the current centering edit.
- Onboarding centers the logo, title, body, three action cards and their contents, and phone pairing separator. A 960×540 widget test checks geometry and screen bounds. Full format, analysis, and test checks passed, and build 16 was visually checked on the physical TV. The user's own viewing remains the final product check.

## Next work

1. When the user reports a new TV issue, reproduce the exact logical viewport in a widget test and validate the resulting build on the physical TV when wireless debugging is available. Avoid exposing the user's library in screenshots or logs.
2. Reconcile the remaining `main` changes into the priority branch deliberately. In particular, review TV landscape navigation, macOS Keychain fallback, source refresh health, artwork storage, and CI/Pages changes. Some main features have already been ported; compare behavior and tests rather than replaying commits blindly.
3. Continue the roadmap's high-value gaps: low-memory device profiling, native playback validation, QR pairing on physical TV, metadata matching validation, and responsive TV/mobile UI.
4. Keep distribution separate from local testing. A push, GitHub release, web deployment, DMG, and APK publication require an explicit release request and successful release checks. Do not claim that a locally installed build is available to download.

## Efficient verification and device policy

Run focused tests first, then `dart run melos run format:check`, `dart run melos run analyze`, and `dart run melos run test` from the repo root. Serialize Flutter native builds. For Android TV use `flutter build apk --release --target-platform android-arm,android-arm64 --build-number N`; inspect the APK architecture and install with `adb install -r`, then read `dumpsys package` and launch state. Do not retain old local APKs after the new one is verified.

The user has asked to stop reinstalling the Mac and iPhone repeatedly when they already work. Install only when the change affects those platforms or the user requests it. Android TV installation requires the user to enable wireless debugging and request it; the current conversation includes that request. If ADB drops, continue independent work and report the unverified install state. Never install on another person's connected phone.
