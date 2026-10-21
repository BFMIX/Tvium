# Tvium Metadata Gateway

A small, dependency-free Node.js 22+ service for public catalog metadata. It accepts only a normalized title, content kind, optional year and language. Playlist files, provider addresses, stream URLs and account credentials must never be submitted. Title searches disclose the submitted title to the selected metadata provider; enable enrichment only with the user's consent.

## Run locally

```sh
cd services/metadata_gateway
npm test
npm start
```

The service binds to `127.0.0.1:8787`. Configure `TMDB_READ_ACCESS_TOKEN` in the server environment using a secret manager or local shell. Never embed it in the app, commit it or paste it into logs. Without this token, series use TVmaze and channels use IPTV-org; movie searches return a generic unavailable response.

For a local macOS preview, run `zsh scripts/run_metadata_preview_macos.zsh` from the repository root. It asks for the TMDB read access token in the Terminal without echoing it, starts the gateway on loopback, and launches Flutter with the local gateway address. The token is never passed to Flutter or written to a file. Enable online metadata in Settings, then open a movie or series and select **Online info**. Closing Flutter also stops the local gateway. Use only a token you are authorized to use, and do not paste it into a chat or commit it.

`PORT`, `HOST` and comma-separated `ALLOWED_ORIGINS` are optional. Browser requests require an exact configured origin. No wildcard origins are accepted. Native requests without Origin are supported. No service is deployed by these instructions. Public hosting requires TLS, authentication/abuse controls and shared rate limiting at the ingress; CORS is not authentication. The in-memory rate limiter uses the direct socket address and deliberately ignores forwarded headers.

## Contract

`POST /v1/search`, `Content-Type: application/json`:

```json
{"title":"Example Movie","kind":"movie","year":2020,"language":"en-US"}
```

Kinds: `movie`, `series`, `live`. Response: `{"candidates":[]}` or up to 20 candidates with `id`, `provider`, `title`, `kind`, `sourceUrl`, `license`, and optional `year`, `posterUrl`, `overview`. A candidate is evidence for local matching, not permission to overwrite playlist identity. `400` invalid input; `413` oversized body; `415` wrong media type; `429` rate limit; `503` unavailable provider. Errors never include upstream details.

## Providers and attribution

- [TMDB search](https://developer.themoviedb.org/reference/search-movie): primary movies/series; [API terms](https://developer.themoviedb.org/docs/faq) require attribution and distinguish commercial use. A free app is not automatically non-commercial. Review licensing before any commercial use. Display the approved TMDB logo and: “This product uses the TMDB API but is not endorsed or certified by TMDB.”
- [TVmaze](https://www.tvmaze.com/api): series fallback, CC BY-SA 4.0; preserve source links and attribution and assess share-alike requirements for redistributed derived databases.
- [IPTV-org](https://github.com/iptv-org/api): exact channel/alias matches against public `channels.json`, cached for 24 hours. No stream endpoint is requested. [Database license](https://github.com/iptv-org/database/blob/master/LICENSE) is public domain; third-party artwork/trademarks have separate rights. Logos are not returned in this first adapter.
- Wikidata enrichment is reserved for a later identifier-based adapter; this service does not query it yet.

Search cache: one hour, 500 entries, memory only. Upstream responses have byte caps, five-second timeouts, fixed HTTPS hosts and redirect rejection. Maximum eight concurrent searches, 60 upstream requests/minute across all clients, 2 KiB request body, titles up to 200 characters and 60 requests/minute per direct client address. No payload or upstream error logging. Tests use synthetic data and mocked providers; live credentials are not required.
