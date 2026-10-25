# Product recommendations for review

These are proposals, not approved requirements. They preserve Tvium's local-first, provider-neutral product boundary and avoid cloud accounts or private playlist uploads.

| Order | Proposal | User benefit | Smallest useful version |
|---|---|---|---|
| 1 | Source health page | A user can tell whether a source refreshed, is waiting, failed, or needs attention without seeing a perpetual spinner. | Implemented in Playlists settings with last success, next check, a generic failure state, and per-source retry; physical-device validation remains open. |
| 2 | Pre-import summary and safe recovery | Large or changed playlists become understandable before they replace a working library. | Show counts by Live/Movies/TV Shows, aggregate changes, and a rollback action for the last successful catalog. |
| 3 | Guided EPG matching | Real Now/Next coverage improves when guide names differ from playlist channel names. | Suggest a small set of local candidate matches, let the user confirm or clear a mapping, and keep the original names. |
| 4 | Storage budget and offline diagnostics | TVs with little free space keep artwork without slowdowns or silent cache growth. | A 256 MiB native startup cap and least recently used eviction have synthetic coverage. Still show cache size, allow clearing, explain offline misses, and validate long sessions on a device. |
| 5 | Local encrypted backup and transfer | A user changing devices can keep profiles and preferences without a Tvium account. | Export an encrypted, user-held file with explicit restore preview; exclude stream URLs from support diagnostics and never upload the file to Tvium. |

Start with source health after release reliability is restored. Validate each proposal against privacy, accessibility, and TV remote use before adding it to [Roadmap](../ROADMAP.md).
