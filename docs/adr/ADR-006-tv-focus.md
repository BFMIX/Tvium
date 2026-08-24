# ADR-006: TV focus architecture

- Status: Accepted
- Date: 2026-08-18

## Context

Adding focus after touch layouts produces lost focus, ambiguous traversal, and unusable remote navigation.

## Decision

Make focus states and semantics part of design-system primitives. Screens define explicit traversal groups and restore focus after navigation, filtering, overlays, and item removal.

## Consequences

Every interactive component carries more state and tests from its creation. Phone and desktop benefit from keyboard accessibility. Real Android TV and Apple TV verification remains mandatory.
