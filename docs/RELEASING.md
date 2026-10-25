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

The `v1.0.0-alpha.14` macOS DMG is ad-hoc signed and is not notarized; macOS
Gatekeeper rejects it. Do not present that download as a ready-to-run Mac app.
Future releases require Developer ID signing and notarization before the DMG
is uploaded. Starting with the first release after
`v1.0.0-alpha.7`, the Android APK uses a persistent release key held outside
the repository and provided to CI through four protected secrets. Older
GitHub APKs used an ephemeral debug key and cannot be updated in place with
the new key; uninstalling them erases their local app data. Keep the release
keystore and password backed up securely: losing them prevents future direct
APK updates. Never commit signing credentials to the repository.

The Android release job requires `TVIUM_ANDROID_KEYSTORE_BASE64`,
`TVIUM_ANDROID_STORE_PASSWORD`, `TVIUM_ANDROID_KEY_ALIAS`, and
`TVIUM_ANDROID_KEY_PASSWORD`. It fails rather than publishing an APK signed
with a runner's debug key when any credential is missing. The signing gate is
covered by `bash scripts/release/test_android_signing_gate.sh`.

The previous ad-hoc macOS build can repeatedly ask for access to the login
Keychain, including after **Always Allow**. Do not ask testers to keep approving
it. The release workflow now requires these protected GitHub Actions secrets:

- `TVIUM_MACOS_DEVELOPER_ID_P12_BASE64`: base64-encoded Developer ID
  Application `.p12` export containing its private key.
- `TVIUM_MACOS_DEVELOPER_ID_P12_PASSWORD`: export password.
- `TVIUM_APPLE_NOTARY_KEY_BASE64`: base64-encoded App Store Connect API `.p8` key.
- `TVIUM_APPLE_NOTARY_KEY_ID` and `TVIUM_APPLE_NOTARY_ISSUER_ID`: identifiers
  for that API key.

The account holder must create the Developer ID certificate and notarization
API key in Apple Developer/App Store Connect, then add the values directly to
GitHub Actions secrets. Never send the private key or export password in chat.
The workflow fails before packaging if any secret is missing. It then:

1. Imports the **Developer ID Application** identity into a temporary CI
   Keychain and keeps its private key outside the repository.
2. Signs executable code with that identity, hardened runtime, required
   entitlements, and a secure timestamp; verify the bundle signature.
3. Submits the DMG with `notarytool`, requires acceptance, staples the ticket,
   and checks Gatekeeper assessment before uploading the file.
4. Requires a clean Mac user account test of first launch and Keychain access.
   Then
   install an update and verify that saved sources remain usable without
   repeated permission dialogs.

Run `bash scripts/release/test_macos_distribution_gate.sh` on macOS to verify
that an ad-hoc signed application is rejected before publication.

An **Apple Development** certificate is insufficient for Developer ID
distribution. Apple documents the [Developer ID and notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [common notarization failures](https://developer.apple.com/documentation/security/resolving-common-notarization-issues).

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
