# Xtream Codes Integration Plan

Xtream support shares the future `PlaylistProvider` domain output with M3U. The first adapter slice now authenticates an account and loads Live TV, VOD, and Series categories and summaries behind credential-safe models.

A profile contains a local name, server URL, username, and password. Credentials are resolved from secure storage and never logged. The adapter will probe account information and load available live, VOD, series, season/episode, and EPG endpoints with bounded concurrency, timeouts, cancellation, and tolerant JSON mapping.

Server responses are untrusted and frequently vary in field type or shape. Mapping therefore accepts documented variants, preserves unknown/raw evidence where safe, and emits per-record warnings instead of crashing an import. Expiration and maximum connections are displayed only when supplied by the server.

The UI consumes common channels, films, series, episodes, groups, and import reports; it does not branch on Xtream except during profile setup and source-specific diagnostics.

Automated tests use fictional `.test` endpoints and credentials. Private user playlists and account details are local runtime inputs only and must never enter source control, fixtures, CI, logs, screenshots, or diagnostic exports.
