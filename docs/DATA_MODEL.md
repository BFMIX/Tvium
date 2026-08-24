# Data Model

## Source preservation

Every imported entry keeps `originalName`, `originalUri`, `originalExtInf`, and an immutable map of original attributes. Tvium derives `normalizedName` and `displayName`; it never rewrites the user's source.

## Core entities

- `Playlist`: local identity, type, display name, status, sync timestamps, and aggregate counts.
- `PlaylistSource`: source kind and opaque reference to protected connection data.
- `MediaGroup`: original and local display names, order, visibility, and playlist relation.
- `Channel`: IPTV identity, names, logo, group, EPG ID, country/language hints, and source references.
- `ChannelVariant`: quality/codec declarations and observed playback properties for one stream.
- `Movie`, `Series`, `Season`, `Episode`: VOD hierarchy with original fields and optional enrichment.
- `EpgProgram`: channel mapping, time range, title, and optional programme details.
- `Favorite`, `HistoryEntry`, `WatchProgress`, `HiddenItem`, `ParentalRule`: user-local overlays that survive source refresh.
- `MetadataCache`: provider, confidence, source timestamp, expiry, and matched fields.

## Identity and synchronization

Imported records use a stable fingerprint derived from playlist identity plus non-secret source evidence. Exact duplicates require equivalent source and technical properties. Quality variants remain separate streams under a canonical channel only when confidence is high. Related channels are never variants.

Refresh computes `added`, `changed`, `removed`, and `unchanged` sets. Removal from a source does not erase user overlays immediately; tombstones allow recovery and prevent favorites or progress from being silently lost.

## Storage schema

The planned indexed tables are `playlists`, `playlist_sources`, `groups`, `channels`, `channel_variants`, `movies`, `series`, `seasons`, `episodes`, `epg_programs`, `favorites`, `history`, `watch_progress`, `hidden_items`, `parental_rules`, `metadata_cache`, and `settings`.

Indexes prioritize playlist/group browsing, normalized-title search, EPG channel/time ranges, series/season/episode order, favorites, and recent history. Schema changes use numbered forward migrations with migration tests. Credentials and full sensitive URLs do not belong in ordinary database columns.
