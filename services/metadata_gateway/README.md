# Tvium Metadata Gateway

A small, dependency-free Node.js 22+ service for public catalog metadata. It accepts only a normalized title, content kind, optional year and language. Playlist files, provider addresses, stream URLs and account credentials must never be submitted. Title searches disclose the submitted title to the selected metadata provider; enable enrichment only with the user's consent.

## Run locally

```sh
cd services/metadata_gateway
npm test
npm start
```

The service binds to `127.0.0.1:8787`. Configure `TMDB_READ_ACCESS_TOKEN` in the server environment using a secret manager or local shell. Never embed it in the app, commit it or paste it into logs. Without this token, series use TVmaze and channels use IPTV-org; movie searches return a generic unavailable response.

For a local macOS preview, run `zsh scripts/run_metadata_preview_macos.zsh` from the repository root. The launcher reads a token from `~/.config/tvium/tmdb-read-token` when that file exists with owner-only permissions (`chmod 600`); otherwise, it asks for the token in an interactive Terminal without echoing it. The token is never passed to Flutter or logged. The launcher starts the gateway on loopback and launches Flutter. Desktop builds also discover the loopback gateway without a special build flag, but the gateway must be running for searches to work. Enable online metadata in Settings; movie and series details then look up metadata automatically, and the displayed Home feature can load verified artwork. Consent and verified public metadata are saved locally; playlist source data remains unchanged. Closing Flutter also stops the gateway started by this launcher. Use only a token you are authorized to use, and do not paste it into a chat or commit it.

`PORT`, `HOST` and comma-separated `ALLOWED_ORIGINS` are optional. Browser requests require an exact configured origin. No wildcard origins are accepted. Native requests without Origin are supported. No service is deployed by these instructions. Public hosting requires TLS, authentication/abuse controls and shared rate limiting at the ingress; CORS is not authentication. The in-memory rate limiter uses the direct socket address and deliberately ignores forwarded headers.

The Web release can be pointed at a hosted gateway by setting the repository variable `TVIUM_METADATA_GATEWAY` to its public HTTPS origin before running the Release workflow. The build rejects credentials, paths, and insecure addresses. This variable is a public endpoint address, never the TMDB token. Leave it unset until the gateway has TLS and ingress protections; setting the variable does not deploy a gateway. Configure `ALLOWED_ORIGINS` on the gateway to permit the deployed Pages origin.

The same server can relay encrypted Web QR pairing. Once hosted over HTTPS, set repository variable `TVIUM_PAIRING_RELAY` to its public origin and configure `ALLOWED_ORIGINS` to include `https://bfmix.github.io`. The release build then displays **Add with your phone** on Web/Tesla. The relay receives only an opaque AES-GCM payload and expires sessions after ten minutes. Do not use a placeholder address: the option must lead to a working phone page. See [QR pairing](../../docs/QR_PAIRING.md).

## Contract

`POST /v1/search`, `Content-Type: application/json`:

```json
{"title":"Example Movie","kind":"movie","year":2020,"language":"en-US"}
```

Kinds: `movie`, `series`, `live`. Response: `{"candidates":[]}` or up to 20 candidates with `id`, `provider`, `title`, `kind`, `sourceUrl`, `license`, and optional `year`, `originalTitle`, `posterUrl`, `backdropUrl`, `overview`. TMDB searches use the requested language, so a localized title can match without replacing the original playlist title. A candidate is evidence for local matching, not permission to overwrite playlist identity. `400` invalid input; `413` oversized body; `415` wrong media type; `429` rate limit; `503` unavailable provider. Errors never include upstream details.

## Providers and attribution

- [TMDB search](https://developer.themoviedb.org/reference/search-movie): primary movies/series; [API terms](https://developer.themoviedb.org/docs/faq) require attribution and distinguish commercial use. A free app is not automatically non-commercial. Review licensing before any commercial use. Display the approved TMDB logo and: “This product uses the TMDB API but is not endorsed or certified by TMDB.”
- [TVmaze](https://www.tvmaze.com/api): series fallback, CC BY-SA 4.0; preserve source links and attribution and assess share-alike requirements for redistributed derived databases.
- [IPTV-org](https://github.com/iptv-org/api): exact channel/alias matches against public `channels.json`, cached for 24 hours. No stream endpoint is requested. [Database license](https://github.com/iptv-org/database/blob/master/LICENSE) is public domain; third-party artwork/trademarks have separate rights. Logos are not returned in this first adapter.
- Wikidata enrichment is reserved for a later identifier-based adapter; this service does not query it yet.

Search cache: one hour, 500 entries, memory only. Upstream responses have byte caps, five-second timeouts, fixed HTTPS hosts and redirect rejection. Maximum eight concurrent searches, 60 upstream requests/minute across all clients, 2 KiB request body, titles up to 200 characters and 60 requests/minute per direct client address. No payload or upstream error logging. Tests use synthetic data and mocked providers; live credentials are not required.
