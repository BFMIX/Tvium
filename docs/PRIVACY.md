# Privacy

Tvium works without an account. Playlist profiles, credentials, library organization, favorites, history, watch progress, and parental settings remain local by default.

Phase 0 includes no product analytics, advertising SDK, remote crash collector, or Tvium backend. Tooling telemetry is disabled in the documented development setup. If optional analytics are considered later, they require explicit opt-in, data minimization, a documented retention period, and proof that credentials, source URLs, stream URLs, titles, and viewing history cannot be included.

Users can remove a playlist and its local data. Future deletion UX must distinguish source index, favorites, history, and cached metadata before destructive action. Cache cleanup must not delete the user's original local playlist.

Debug reports are local and sanitized. Exporting any source configuration requires confirmation and a clear sensitive-data warning.
