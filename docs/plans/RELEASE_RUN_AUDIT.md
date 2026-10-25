# Release run audit

**Checked:** 25 October 2026. This classifies the previously investigated failed GitHub Actions runs. Historical failures remain visible in GitHub; a later successful run does not erase them.

| Runs | Cause | Current state |
|---|---|---|
| `39077568797`, `39077711478` | Early alpha.1/alpha.2 macOS build failures; alpha.1 also failed Pages configuration. | Later macOS builds and Pages deployments pass. |
| `33428998281` | Old Dependabot `file_picker` update made `android_file_picker` incompatible with the platform interface. | Historical dependency PR failure; current workspace tests pass. |
| `39971118615` | Run canceled during release iteration after an Android signing-gate failure. | Not a published release. |
| `39971793925`, `40071373237`, `40072008404`, `40072579302` | Android APK certificate extraction failed in CI. The APK preserved from `40072579302` was independently verified to carry the expected release certificate; the automatically selected SDK verifier did not report it. | The workflow now pins the tested Android SDK Build Tools 34.0.0 verifier. |
| `40071373237` | Pages rejected the review branch under its environment branch policy. | The branch was added to the allowed policy; subsequent Pages deployments pass. |

Run `40073065845` passed macOS, Android, Web, Pages, and publication. It published [alpha.8](https://github.com/BFMIX/Tvium/releases/tag/v1.0.0-alpha.8). The downloaded Android APK matched the release asset digest and expected public signing certificate. The macOS DMG is still ad-hoc signed and should be treated as a test build pending Developer ID signing and notarization.

Web QR pairing was unavailable in the alpha.8 release. The native implementation accepts submissions through a local HTTP server, which a GitHub Pages browser cannot host. Commit `8272cf2` prepared a separately hosted HTTPS relay, encrypted phone submission, and Web client. The Netlify relay passed synthetic end-to-end and cross-deploy checks. Run `40095004311` published [alpha.10](https://github.com/BFMIX/Tvium/releases/tag/v1.0.0-alpha.10): macOS, Android, Web, Pages, and GitHub Release jobs passed. The public Pages first-launch screen visibly offers phone pairing and opens a QR dialog. Tesla hardware scanning and source import still need physical validation.

PRs [#17](https://github.com/BFMIX/Tvium/pull/17) and [#18](https://github.com/BFMIX/Tvium/pull/18) passed both protected-branch checks and were squashed into `main`. Run [`40149791776`](https://github.com/BFMIX/Tvium/actions/runs/40149791776) passed Android APK, macOS DMG, Web archive, Pages deployment, and release publication. [Alpha.11](https://github.com/BFMIX/Tvium/releases/tag/v1.0.0-alpha.11) has all three download assets and targets the same commit as `main`, `1186a116765bf5cf7084760fcb6f0b6117ad2a15`. This confirms a matching release build; it does not establish physical TV pairing, native playback, or notarized macOS distribution.
