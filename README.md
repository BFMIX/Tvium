<div align="center">

# Tvium

### One IPTV player. Every screen.

**Your sources. Your library. Your screens.**

[![Project status](https://img.shields.io/badge/status-in%20development-18B7A0)](docs/ROADMAP.md)
[![Platforms](https://img.shields.io/badge/platforms-Web%20%7C%20Mobile%20%7C%20TV%20%7C%20Desktop-111827)](#designed-for-every-screen)
[![CI](https://github.com/BFMIX/Tvium/actions/workflows/ci.yml/badge.svg)](https://github.com/BFMIX/Tvium/actions/workflows/ci.yml)

</div>

Tvium is a modern, all-in-one IPTV player designed to bring live television, movies, and series from user-provided sources into one clean, organized experience.

Use the same familiar player in a Web browser, on a phone or tablet, on a computer, or across the living room on a TV and compatible streaming box.

> [!IMPORTANT]
> Tvium is a media player. It does not provide TV channels, playlists, subscriptions, or access to any IPTV provider. Users are responsible for their sources and for ensuring they have the right to access the content they play.

## Everything in one place

- **Live TV** — browse channels by group and start watching without navigating through complex menus.
- **Movies and series** — turn compatible sources into a visual, easy-to-explore library.
- **Your own sources** — import playlists you already have; Tvium does not lock you into a provider.
- **A consistent experience** — move between small touchscreens, desktops, browsers, TVs, and remote controls without learning a different app each time.
- **Built for large libraries** — progressive loading keeps browsing responsive as collections grow.
- **Privacy first** — source details and viewing data are designed to remain local, with no advertising or tracking.
- **Clean by design** — content stays at the center, with focused navigation and a calm interface.

## Designed for every screen

Tvium is being built as one cross-platform product rather than a collection of unrelated players.

| Screen | Planned experience |
|---|---|
| **Web** | Watch from a modern browser without installing a desktop app. |
| **Phone and tablet** | Touch-friendly playback on Android, iPhone, and iPad. |
| **TV and streaming box** | Remote-first navigation for Android TV, Google TV, Apple TV, and compatible boxes. |
| **Desktop** | A full library experience on macOS and Windows. |

Platform availability will be announced only after testing on the relevant devices.

## Sources and organization

Tvium currently focuses on progressive **M3U and M3U8** import. The product roadmap also covers Xtream-compatible connections, programme guides, source refresh, favorites, history, parental controls, and richer organization for movies and series.

Source metadata is preserved so Tvium can improve presentation without silently changing the user's playlist.

## Development status

Tvium is in active development and is **not yet available as a public download**. The Phase 0 prototype has validated:

- M3U file and URL import;
- grouped Live, Movies, and TV Shows views;
- keyboard and TV-style focus navigation;
- a cross-platform HLS playback foundation;
- Web and macOS development builds;
- progressive parsing of synthetic playlists containing up to 100,000 entries.

See the [Phase 0 report](docs/PHASE_0_REPORT.md) for verified results and current limitations, or follow the [product roadmap](docs/ROADMAP.md).

## Privacy and safety

Tvium is local-first. Playlist addresses, credentials, private stream URLs, and viewing activity must never be committed to this repository or exposed in diagnostics. The project includes sanitization boundaries specifically for sensitive source information.

Please report security issues privately through GitHub's **Security** tab. Do not open a public issue containing credentials, playlist URLs, or personal data.

## For contributors

<details>
<summary>Local setup and verification commands</summary>

Install Flutter stable, then run from the repository root:

```bash
flutter --disable-analytics
dart pub get
dart run melos bootstrap
dart run melos run format:check
dart run melos run analyze
dart run melos run test
```

Launch the macOS prototype with:

```bash
cd apps/tvium_app
flutter run -d macos
```

</details>

Before contributing, read [Contributing](CONTRIBUTING.md), [Architecture](docs/ARCHITECTURE.md), and [Security](docs/SECURITY.md). Pull requests must use fictional `.test` fixtures and must never contain real IPTV credentials or copyrighted channel branding.

## License

No open-source license has been selected yet. Until a license is published, normal copyright restrictions apply. See the [licensing decision](docs/LICENSING_DECISION.md) for the current position.
