# ADR-007: Riverpod and go_router

- Status: Accepted
- Date: 2026-08-18

## Context

Imports emit long-running progress, cancellation, results, and failures. Navigation must support adaptive shells and future deep links without business state in widgets.

## Decision

Use Riverpod for dependency injection and state orchestration, and go_router for declarative navigation. Keep domain use cases framework-independent.

## Consequences

Async state and test overrides are explicit. The app accepts two dependencies but avoids a custom service locator or navigation framework. Route changes do not own media/library persistence.
