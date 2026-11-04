# Privacy

Tvium works without an account. Playlist profiles, credentials, library organization, favorites, history, watch progress, and parental settings remain local by default.

Tvium includes no product analytics, advertising SDK, or remote crash collector. Tooling telemetry is disabled in the documented development setup. If optional analytics are considered later, they require explicit opt-in, data minimization, a documented retention period, and proof that credentials, source URLs, stream URLs, titles, and viewing history cannot be included.

Tvium Web uses a Tvium-hosted HTTPS relay when contacting playlist providers and playing supported browser media. This relay receives the provider address and, when present, playlist credentials during each request. Its application code does not store the playlist, catalog, or media stream; playback links hide provider details and expire. A provider reached over HTTP is not protected by HTTPS on the relay-to-provider connection. Native applications normally contact providers directly. The relay is part of normal Web operation and does not display a separate confirmation dialog before every import. See `WEB_PLAYLIST_RELAY.md` for technical limits.

Users can remove a playlist and its local data. Future deletion UX must distinguish source index, favorites, history, and cached metadata before destructive action. Cache cleanup must not delete the user's original local playlist.

Debug reports are local and sanitized. Exporting any source configuration requires confirmation and a clear sensitive-data warning.
