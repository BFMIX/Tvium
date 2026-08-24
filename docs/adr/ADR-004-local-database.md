# ADR-004: Local database boundary

- Status: Accepted
- Date: 2026-08-18

## Context

Large playlists require indexed browsing, search, incremental refresh, and durable user overlays.

## Decision

Define repository contracts in `tvium_database` and target Drift/SQLite for native platforms. Phase 0 may use an in-memory implementation while measuring parser behavior; durable schema implementation follows with migration tests.

## Consequences

Domain/UI code does not depend on SQL. Native indexing can scale independently. Web persistence remains a separate decision because security, browser quotas, and SQLite/WASM behavior differ.
