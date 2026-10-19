# Shared Sources and Lightweight Profiles

## Status

Approved product direction. This document defines the persistence and user-flow architecture that must be implemented before favorites, history, and parental controls.

## Goals

- Restore IPTV sources and the active profile after an application restart.
- Let multiple household profiles use the same IPTV source without duplicating credentials, catalog rows, or refresh work.
- Keep source management simple enough for phone, desktop, and TV remotes.
- Preserve a strict boundary between ordinary application data and sensitive connection data.
- Provide stable foundations for profile-specific favorites, history, progress, and parental controls.

## Non-goals

- Cloud accounts or cross-device synchronization.
- Remote backup of credentials.
- Final visual styling of the profile selector.
- Full Series season and episode support.
- Provider sharing between different Tvium installations.

## User Experience

Tvium creates a local `Home` profile on first launch. Adding an M3U or Xtream source automatically attaches it to the active profile and opens its library.

The header exposes one Profile action. It opens a compact surface containing:

1. Existing profiles, with the active profile clearly marked.
2. `Add profile` and `Manage sources` actions.
3. Rename and delete actions inside profile management, not in the primary switcher.

Adding a source that already exists does not create a second catalog. Tvium explains that the existing source was linked to the active profile. Removing a source from one profile only removes that relationship. Tvium deletes the shared source and its protected credentials only after no profile references it and the user confirms the deletion.

The first implementation may use a functional dialog or sheet. The approved production visual direction will be applied later without changing the data model.

## Domain Model

### UserProfile

- `id`: random opaque identifier.
- `displayName`: user-visible local name.
- `createdAt` and `updatedAt`.
- `isActive` is represented by one application setting rather than duplicated on every row.

### IptvSource

- `id`: random opaque identifier shared by every linked profile.
- `kind`: `m3uUrl`, `m3uFile`, or `xtream`.
- `displayName`: editable user-visible label.
- `secretReference`: opaque key for protected connection data.
- `identityDigest`: local deterministic digest used only for duplicate detection.
- `status`, refresh timestamps, and aggregate counts.

The digest is derived from a versioned canonical identity through a device-local keyed HMAC. The HMAC key remains in secure platform storage so ordinary database access cannot be used to test guessed credentials or URLs. Xtream identity uses the normalized server origin and normalized username. URL sources use the canonical URL. Local files use a content fingerprint rather than a machine-specific path. The digest is never displayed or logged.

### ProfileSource

A many-to-many relation between `UserProfile` and `IptvSource`, with local ordering and visibility. Its composite identity is `(profileId, sourceId)`.

### Catalog Data

Catalog entities belong to `IptvSource`, never directly to a profile. Profile-specific overlays reference stable catalog identifiers plus `profileId`.

## Security Boundary

Secure platform storage contains server URLs, usernames, passwords, and sensitive M3U URLs. SQLite contains only opaque references and non-sensitive catalog projections. Playback URLs are constructed on demand at the playback boundary and are never persisted, logged, included in errors, or exposed through debug labels.

Duplicate detection occurs locally. Tvium computes identity digests through a dedicated service that returns only the digest; callers must not receive or retain canonical secret input. A version prefix allows future digest changes without silently merging unrelated sources.

Local file sources cannot be assumed to remain accessible after restart on every platform. The source record remains visible, but Tvium must request the file again when a persistent platform bookmark or copied private file is unavailable.

## Persistence Architecture

The database package owns profile, source, relation, and catalog repository contracts. Drift/SQLite provides the native implementation and numbered forward migrations. The application depends on repository interfaces injected through Riverpod.

Startup follows this sequence:

1. Open the repository.
2. Create `Home` if no profile exists.
3. Restore the active profile, falling back to the oldest profile.
4. Load its linked sources and cached catalog projections.
5. Render onboarding only when the active profile has no usable source.

Web uses the same contracts but requires a separate persistence adapter. Until that adapter is implemented, Web must clearly describe session-only behavior rather than claim durable storage.

Writes that create a source, link it to a profile, and replace its catalog must be atomic where possible. Secure storage cannot share a SQLite transaction, so failures use compensating cleanup: credentials written for a database operation that fails are removed immediately.

## Duplicate Handling

When a source is added:

1. Validate and canonicalize its identity inside the protected identity service.
2. Search by `identityDigest` and `kind`.
3. If no source exists, create the secure secret, source row, profile link, and catalog.
4. If a source exists, update credentials only after successful authentication, then create the missing profile link.
5. If the profile already links that source, refresh the existing source instead of creating any rows.

Matching a duplicate never combines two distinct provider accounts merely because their catalogs look similar.

## Error Handling

- Storage and migration failures produce recoverable, sanitized application errors.
- Missing protected credentials mark a source as requiring reconnection; they do not delete its catalog automatically.
- A failed refresh preserves the last successful catalog.
- Deleting the active profile requires choosing a replacement or automatically selecting the oldest remaining profile.
- The final remaining profile cannot be deleted; it can be renamed or reset.

## Testing Strategy

- Repository contract tests cover default-profile creation, profile switching, source linking, unlinking, and orphan deletion.
- Migration tests preserve existing media entries while adding the new tables.
- Identity tests prove canonical duplicates match and distinct accounts remain separate without printing canonical inputs.
- Service tests cover secure-write compensation and credential updates after successful authentication only.
- Widget tests cover restart restoration, duplicate-source messaging, profile switching, and remote/keyboard access.
- Existing M3U, Xtream, playback, security, Web build, and macOS build checks remain required.

Tests use synthetic `.test` hosts and fixture credentials only. Private playlists and provider data must never enter fixtures, snapshots, logs, or CI.

## Delivery Sequence

1. Add domain models and repository contracts with in-memory contract tests.
2. Add Drift tables and a forward migration with migration tests.
3. Add the protected source-identity and source-registration services.
4. Restore the active profile and linked library during application startup.
5. Add the compact profile switcher and source-management flows.
6. Add profile-scoped overlay foundations for favorites and history.

Each step must leave existing M3U and Xtream imports usable and independently testable.
