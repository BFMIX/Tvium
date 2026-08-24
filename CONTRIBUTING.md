# Contributing to Tvium

Thank you for helping improve Tvium. Contributions should support a fast, private, and consistent IPTV player across Web, mobile, desktop, TV, and streaming-box experiences.

## Before You Start

Open an issue before undertaking a large feature or architectural change. Keep pull requests focused and follow the product boundaries in `docs/SCOPE.md`.

Never submit real playlists, credentials, private stream URLs, provider accounts, personal viewing data, or copyrighted channel artwork. Test fixtures must use fictional metadata and reserved `.test` domains.

## Local Checks

Run these commands from the repository root before opening a pull request:

```bash
dart run melos run format:check
dart run melos run analyze
dart run melos run test
```

Visible changes should also be tested at relevant screen sizes and with keyboard or remote-style focus navigation.

## Commits and Pull Requests

Use focused Conventional Commits, such as `feat(m3u): preserve source groups` or `fix(player): recover after buffering`. A pull request should explain the user-facing change, list verification performed, link related issues, and include screenshots or recordings for visual work.

State platform limitations explicitly. A successful build on one platform does not prove playback behavior on another.
