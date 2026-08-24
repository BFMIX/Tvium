# ADR-001: Flutter and Dart

- Status: Accepted
- Date: 2026-08-18

## Context

Tvium targets phones, tablets, desktops, Web, Android TV, and Apple TV while sharing playlist and library logic.

## Decision

Use Flutter stable and null-safe Dart as the primary application stack in a modular workspace. Native platform code remains allowed where player, remote, lifecycle, packaging, or Store requirements demand it.

## Consequences

Most domain and UI code is shared. tvOS and specialized playback still require spikes and may need maintained platform channels or plugins. Shared code does not imply identical layouts or codec support.
