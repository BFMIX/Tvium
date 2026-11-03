# Temporary browser playlist relay

The GitHub Pages app cannot fetch an arbitrary IPTV provider directly when the
provider uses HTTP or omits browser CORS headers. Phone pairing delivers only
the source configuration; it does not download the playlist.

For Web M3U imports, the user must confirm that the Tvium Netlify relay will
temporarily receive the provider URL and any credentials embedded in it. The
browser obtains a 10-minute viewer token from the pairing service, then sends
the URL in a POST body to `/v1/playlist-fetch`. The Edge Function validates the
same HMAC token as pairing, rejects local/private addresses and redirects,
fetches once, and streams the response without caching or application logging.
It does not store playlist data. The M3U client never displays the source URL
in an error message.

The relay is intended only for M3U catalog requests. It does not proxy Xtream
API calls, artwork, EPG, or media playback. Browser playback remains dependent
on the provider's HTTPS and browser support. The Edge Function has a 40-second
response-header limit; very slow providers may still fail. This is a temporary
compatibility path, not proof that every provider works in Tesla's browser.

Deploy the gateway from `services/metadata_gateway` with Netlify CLI and verify
the Edge Function on a draft deploy using synthetic public URLs before
publishing it. Then deploy the GitHub Pages app from `main`. Never put a real
provider URL or credentials in tests, logs, screenshots, or issue comments.
