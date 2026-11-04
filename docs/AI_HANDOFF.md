# Tvium development handoff

Updated: 2026-11-04. Read `AGENTS.md` before editing.

## Source of truth and privacy

- The main development checkout is `/Users/bfmix/Desktop/DEv/Project/Tvium Player` on `codex/tvium-priorities` (last inspected at `0009043`). It has pre-existing uncommitted `AndroidManifest.xml` and `pubspec.yaml` edits. Do not overwrite them.
- `main` is the production Web source and diverges substantially from `codex/tvium-priorities`. The Web relay/playback work was prepared in a separate `main`-based worktree at `/Users/bfmix/.codex/worktrees/tvium-web-playback-relay/Tvium Player`. Check current commits and status before merging either direction. Never describe a `main` build as the complete priority branch.
- Keep private playlists, hostnames, credentials, stream URLs, and catalog entries out of Git, diagnostics, tests, screenshots, and AI output. Use synthetic `.test` fixtures.

## Web relay and release

- `docs/WEB_PLAYLIST_RELAY.md` explains the Web import and playback relays. Web M3U and Xtream requests use the HTTPS import relay; browser HLS and supported VOD URLs use short-lived opaque relay links. Native clients retain direct provider access. A relay cannot guarantee that a provider responds or that its codec is supported. Browser MPEG-TS streams without a provider HLS alternative remain unsupported.
- Netlify `tvium` hosts the gateway. GitHub Pages serves the Flutter Web app from `main`. The `Deploy Web` workflow runs automatically only for `main`; do not manually dispatch it on a different branch to publish production.
- On 2026-11-04 the `github-pages` environment branch restriction was removed. `main` required PR reviews and required checks were removed; force pushes and branch deletion remain disabled. This permits direct fast-forward pushes, but tests must still be run before pushing.
- The Netlify media relay was tested with a synthetic public HLS manifest, variant, and segment. The user's private Tesla stream, its codec, and its actual playback have **not** been verified. Check live deployment status and current code before claiming otherwise.

## Verification and devices

- Run `dart run melos run format:check`, `dart run melos run analyze`, `dart run melos run test`, and a Flutter Web release build for Web changes. Run gateway `node --test` and `npm run build:pairing` after gateway changes. These checks passed for the 2026-11-04 Web relay patch before the release; verify the current commit separately.
- Do not reinstall Mac or iPhone for Web-only changes. Build Android TV universal ARM32/ARM64 release APKs only from the intended branch and install only when wireless debugging is enabled and the user requests it. Confirm installed package version after installation. Keep one current local APK.

## Onboarding work prepared after the Web relay release

- The shared Flutter onboarding has manual choices on the left and an automatically created QR pairing session on the right at wide viewports. Narrow phone viewports omit the QR listener. A received QR source starts import automatically, with a success notice after import; the relay consent popup has been removed from Web import. Xtream entry takes only server URL, username, and password; its display name derives from the server host. Source URLs start visible; only passwords start obscured. The short TV viewport and remote focus have widget coverage. Check current Git status/commit and release state before describing this as deployed.
- `docs/QR_PAIRING.md` describes the present phone web form and the proposed separate existing-phone-playlist handoff. No native phone source chooser, deep-link scanner, or encrypted source transfer from the installed phone app exists yet. Do not claim that QR scanning synchronizes an existing phone library.
