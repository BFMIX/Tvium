# ADR-003: Playback abstraction

- Status: Accepted
- Date: 2026-08-18

## Context

No single video engine offers identical lifecycle, codec, track, HLS, remote, and packaging behavior on all targets.

## Decision

Expose an engine-neutral `PlaybackEngine` and typed playback models. Keep concrete plugin/native types inside adapters. Use media_kit only for the Phase 0 HLS spike.

## Consequences

UI and library logic can survive engine changes. Adapters require mapping and platform tests. media_kit compatibility in Phase 0 is evidence, not a permanent cross-platform commitment.
