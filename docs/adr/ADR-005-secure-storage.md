# ADR-005: Secure credential storage

- Status: Accepted
- Date: 2026-08-18

## Context

M3U and Xtream profiles can embed usernames, passwords, and tokens in URLs.

## Decision

Store credentials through a platform secure-storage interface backed by system credential facilities where available. Persist only opaque references in ordinary library records. Default Web credentials to session scope unless users explicitly accept persistence risk.

## Consequences

Source access requires asynchronous secret resolution and adapter error handling. Diagnostics and exports must sanitize independently; secure storage alone does not make logging safe.
