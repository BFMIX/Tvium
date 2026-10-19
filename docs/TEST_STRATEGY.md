# Test Strategy

## Layers

**Unit tests** cover M3U syntax and attributes, malformed recovery, normalization, content classification, series naming patterns, quality tags, duplicate/variant confidence, typed failures, and sensitive-data sanitization.

**Integration tests** cover file and HTTP source boundaries, cancellation, batch import, repository behavior, migrations, EPG association, and playback state mapping. Network tests use controlled local/fake clients, never live provider credentials.

**Widget tests** cover onboarding, loading/progress, preview/report, empty/error states, adaptive breakpoints, localization, accessibility labels, logo fallback, and keyboard/D-pad focus restoration.

**Platform tests** cover builds and manual smoke checks for the player, remote/media keys, background behavior, safe areas, and lifecycle. A build is not a runtime pass.

## Scale and performance

The deterministic generator produces 1,000, 10,000, 50,000, and 100,000 entries. Benchmarks record parsed/warned counts, wall time, throughput, current/peak resident memory when exposed, hardware, OS, Flutter/Dart versions, and command. A checked-in 15,000-entry file is avoided; generation prevents repository bloat.

Large-import acceptance requires a responsive UI isolate, bounded batches, virtualized rows, lazy images, and no all-entry widget construction. Performance thresholds are established from Phase 0 evidence rather than invented beforehand.

## Quality gates

Every behavior change includes a test or a documented reason. Fixes require regression tests. Before commit and CI: format check, strict analysis, all tests, and `git diff --check`. Player compatibility claims require runtime evidence on the named platform and stream format.

CI also compiles the macOS debug app, the Android ARM64 release APK, and the Web release bundle. The macOS job audits sandbox entitlements. Build success is a packaging gate, not proof of playback or device behavior.

Fixtures use `.test` hosts, fictional names, and no recognizable protected marketing assets.
