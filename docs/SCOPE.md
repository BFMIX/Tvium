# Scope

## Phase 0

Phase 0 delivers:

- a Flutter/Dart monorepo and continuous integration;
- product, architecture, UX, security, testing, and legal documentation;
- a progressive M3U reader for local files and remote URLs;
- preservation of original M3U lines, names, URIs, and attributes;
- basic group and media-kind classification;
- resilient per-entry errors and a sanitized import report;
- a deterministic synthetic playlist generator and parser benchmarks;
- adaptive onboarding, import, group, channel, logo-fallback, and player screens;
- an engine-neutral playback contract and provisional HLS adapter;
- keyboard and D-pad focus foundations.

## Deferred

Xtream endpoints, full XMLTV/EPG, durable SQLite indexing, incremental playlist synchronization, canonical-channel variants, complete VOD/series reconstruction, favorites, history, parental controls, Picture in Picture, and production platform adapters remain later milestones. Their boundaries are documented now where they affect Phase 0 choices.

## Explicit V1 exclusions

Tvium V1 will not include recording, stream downloading, a Tvium/cloud account, cloud synchronization, advertising, subscriptions, premium payments, multi-view, social/community features, provider discovery, bundled sources, AI recommendations, a Web proxy, advanced casting/AirPlay, voice search, or cloud profiles.

## Non-goals and acceptance

Phase 0 does not claim universal codec or platform compatibility. A platform is marked verified only after a build or runtime exercise on that platform. Completion requires passing format, analysis, and automated tests; measured parser results at 1k, 10k, 50k, and 100k entries; evidence of available HLS behavior or a documented environment blocker; and `PHASE_0_REPORT.md`.
