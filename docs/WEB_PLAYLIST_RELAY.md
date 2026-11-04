# Browser provider relay

GitHub Pages cannot reliably contact arbitrary IPTV providers from a browser:
HTTP sources can be blocked as mixed content and providers may omit CORS
headers. Web M3U and Xtream imports now use the Tvium HTTPS relay. Native apps
still contact providers directly. Phone pairing transfers source configuration
and requires a separate catalog fetch.

Before a Web import or Xtream connection test, the user confirms that the
relay will see the provider address and credentials during the request. The
browser obtains a short-lived viewer token from pairing and sends the source
URL in a POST body to `/v1/playlist-fetch`. The relay rejects private/local
IP literals and redirects, streams the response, and does not cache, log, or
persist the catalog in application code. The provider connection may itself
be HTTP, so the relay does not provide end-to-end encryption to the provider.

Web playback creates a short-lived, encrypted media URL through
`/v1/media-session`. `/v1/media/*` relays HLS manifests and their referenced
segments and supports Range requests for direct video files. Provider URLs and
credentials are absent from these media URLs. The player exposes a direct
user-gesture Play/Retry control because browsers can reject delayed autoplay.

This is a compatibility path, not a guarantee that every stream plays in every
browser. Direct MPEG-TS and codecs unsupported by the device remain
incompatible without transcoding or an HLS alternative from the provider.
Netlify Edge Functions have a 40-second response-header limit; a provider
that delays headers beyond that limit can still fail. Monitor relay bandwidth
and abuse before broad public distribution of media proxying.

Deploy the gateway from `services/metadata_gateway` using the Netlify CLI and
verify a draft deployment with synthetic public URLs. Deploy the Web app from
`main` after local checks. The GitHub Pages environment accepts all branches,
but `.github/workflows/pages.yml` pushes to production automatically only from
`main`. Avoid manually dispatching a production Pages workflow from a feature
branch. Never include real provider data in tests, logs, screenshots, or issues.
