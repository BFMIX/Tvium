# ADR-002: Local-first operation

- Status: Accepted
- Date: 2026-08-18

## Context

Tvium has no account and handles sensitive source credentials plus private viewing state.

## Decision

Keep source profiles, library indexes, preferences, history, and progress on the device by default. Add no Tvium backend or mandatory telemetry in V1.

## Consequences

The app works without registration and minimizes exposure. Cross-device synchronization and recovery are unavailable until a separate, opt-in design is approved. Platform backup behavior must be documented before release.
