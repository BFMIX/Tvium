# Release Guide

Tvium publishes three testable downloads from one GitHub Actions workflow:

- `Tvium-macOS.dmg` for macOS test installs produced by the current runner.
- `Tvium-Android-TV-arm64.apk` for 64-bit Android phones, tablets, TVs, and boxes.
- `Tvium-Web.zip` containing the static Web build.

The same workflow deploys the Web build to GitHub Pages with the repository
base path `/Tvium/`.

Each tagged build embeds its release tag. Tvium checks public GitHub releases
on startup, announces a newer published version, and offers a manual check in
Settings > Updates. A source-code push without a release does not create an
installable update. Development builds do not check for updates.

## Create a Test Release

1. Open **Actions > Release > Run workflow** in GitHub.
2. Enter a unique semantic tag such as `v1.0.0-beta.1`.
3. Keep **prerelease** enabled while builds are intended for testing.
4. Wait for the macOS, Android, Web, Pages, and release jobs to pass.
5. Download the files from the generated GitHub Release.

The repository's Pages source must be set to **GitHub Actions**. Private
repository Pages availability depends on the GitHub account plan. When Pages
is unavailable, the workflow still publishes the downloadable Web archive and
skips only the deployment job.

## Signing Status

Current artifacts are suitable for private testing only. The macOS app is
ad-hoc signed and is not notarized. The Android APK uses the project's temporary
debug signing configuration. Store distribution requires protected signing
credentials, Apple notarization, and an Android upload key. Never commit those
credentials to the repository.

Automatic installation stays disabled until a signed macOS appcast and
platform-specific distribution paths are configured. iOS and Store-distributed
apps use their Store's update mechanism; Google Play in-app updates do not
support Android TV. The Web release is refreshed by redeploying Pages and
reloading the browser.

## Local Packaging

After a successful release build, create the same archives locally:

```bash
scripts/release/package_macos_dmg.sh \
  apps/tvium_app/build/macos/Build/Products/Release/Tvium.app \
  dist/Tvium-macOS.dmg

scripts/release/package_web.sh \
  apps/tvium_app/build/web \
  dist/Tvium-Web.zip
```

Both scripts refuse to overwrite existing output files.
