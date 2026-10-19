# ADR-008: Platform-native playback adapters

- Status: Accepted
- Date: 2026-09-10

## Context

Tvium needs consistent navigation and library behavior across phones, browsers, computers, TVs, and streaming boxes. Playback capabilities, codecs, lifecycle rules, remote controls, and Store requirements differ substantially by platform. The Phase 0 `media_kit` adapter proved the shared playback boundary but exposed maintenance and Apple build-tooling risks.

## Decision

Keep Flutter for the shared application, presentation, and domain layers while selecting a playback adapter per platform:

- AVPlayer for Apple platforms;
- Media3/ExoPlayer for Android and Google TV;
- HTML5 media with HLS.js fallback behavior for Web;
- a separately evaluated native engine for Windows;
- a native SwiftUI/AVPlayer companion for tvOS, which Flutter does not officially support.

All adapters implement the engine-neutral `PlaybackEngine` contract. UI and library packages never import a native player API directly. Drift/SQLite provides native indexed persistence; Web persistence remains an explicit adapter with browser-specific privacy and capacity behavior.

## Consequences

Tvium retains one product experience without pretending that every platform has the same media stack. Each adapter needs its own lifecycle, codec, track, subtitle, recovery, and device test matrix. The provisional `media_kit` implementation remains until replacement adapters meet equivalent verified behavior.
