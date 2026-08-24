# Security

## Sensitive data

M3U and Xtream URLs, usernames, passwords, tokens, stream paths, query values, and playlist files are confidential. Tvium must not send them to analytics, crash reporting, hosted Tvium infrastructure, or normal logs.

## Storage

Credentials use Android Keystore, Apple Keychain, macOS Keychain, or Windows credentials through a replaceable secure-storage adapter. Indexed records reference protected secrets by opaque ID. Web persistence is opt-in, warns about browser risk, and defaults to the local session until a storage design is approved.

Parental PINs are salted and processed through an approved password hashing primitive; plaintext PINs are never stored. Export requires confirmation and explains which sensitive fields are included.

## Network

HTTP is permitted because user sources may require it, but the UI labels an insecure source. HTTPS certificate verification is never disabled. Clients enforce finite connect/read timeouts, bounded redirects, response-size controls, and cancellation. Browser CORS and mixed-content failures produce actionable errors; Tvium does not proxy streams in V1.

## Logging and diagnostics

All diagnostic text passes through `SensitiveDataSanitizer`. It removes user info, query values, fragments, and sensitive path segments from URLs and redacts known credential keys. Source objects must not rely on `toString()` for logging. Debug playback data may include engine, codec, resolution, bitrate, buffer, dropped frames, and state, but not a full URI.

## Threat controls

- Treat playlist contents and metadata as untrusted input.
- Bound line lengths, entry counts, image sizes, redirects, retries, and concurrent requests.
- Never execute or render playlist text as markup.
- Load images lazily and always provide a safe fallback.
- Do not scan every stream continuously; health checks are user-initiated and rate-limited.
- Keep fixtures fictional and ignore local real playlists with `*.m3u.local`.

Security defects that expose credentials block release.
