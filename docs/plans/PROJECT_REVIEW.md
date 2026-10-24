# Project review

**Snapshot:** 24 October 2026, branch `codex/tvium-repo-review`. This review combines the checked-out code with separately verified release results; it is not a physical-device test.

## What is worth keeping

- The workspace has seven focused reusable packages plus the Flutter app and optional metadata gateway. These boundaries are active and should stay.
- Platform icon copies and the approved design assets serve different build targets or visual roles. Identical file bytes alone are not evidence that an icon can be removed.
- `docs/SCOPE.md` defines V1 exclusions; `docs/PHASE_0_REPORT.md` records historical verification. Keep both, with their roles made explicit in the documentation index.
- Synthetic fixtures and generated localization/database sources support tests and builds. Do not replace them with real playlist data or delete them as apparent duplicates.

## Cleanup completed in this review

- Replaced four generated package README templates, two placeholder changelog entries, and stale scaffolding comments with accurate workspace descriptions.
- Added a documentation index and separate approved and proposed plans, so the long roadmap remains evidence rather than the only task list.
- Removed only regenerable build outputs in this attached worktree after the workspace checks passed. Local source files, secrets, user data, and the primary checkout were not touched.

## Risks and debt to address deliberately

| Area | Evidence in this checkout | Next safe action |
|---|---|---|
| Release trust | Alpha.8 was published by successful run `40073065845`: Android signing, macOS and Web builds, Pages deployment, and release publication passed. The downloaded APK's SHA-256 and release certificate were checked independently. The macOS DMG is still ad-hoc signed. | Keep the Android verifier pinned to the tested SDK version. Obtain Developer ID and notarize macOS before calling it a normal installer. See [Release run audit](RELEASE_RUN_AUDIT.md). |
| Public metadata | The desktop preview can use a local gateway. Public Web/mobile builds still need a hosted HTTPS gateway and server-side token. | Host and protect the gateway, verify provider terms, then test from a clean install. |
| Main UI maintainability | `home_screen.dart` is over 5,000 lines and `tvium_shell_test.dart` over 2,000. | Extract one screen or behavior at a time behind existing tests; avoid a wholesale rewrite. |
| Device evidence | TV remote, QR pairing, image-cache eviction, Android playback, and Windows/tvOS behavior lack complete physical or platform-specific evidence. | Use a device matrix with synthetic or public test content; record build, runtime, and limitations separately. |
| Documentation drift | Phase 0 pages describe earlier milestones, while the roadmap records later verified work. | Treat Phase 0 pages as historical, keep this index current, and update plans after verified changes. |

## Cleanup boundary

The checkout contained about 4.8 GB, primarily ignored Flutter, Dart, Gradle, test, and Xcode outputs. These are rebuildable and are not part of Git. Delete only the identified build directories; do not use a blanket `git clean -X`, which would also remove local configuration or private working files. Rebuilds will temporarily use more disk and time again.
