# tvium_playback

Playback contracts, state transitions, and the current `media_kit` adapter for Tvium. The application uses `PlaybackEngine` so platform-specific playback can change without rewriting library or player controls.

Import `package:tvium_playback/tvium_playback.dart` for the engine interface, media source, playback state, and provisional adapter.

See [Playback](../../docs/PLAYBACK.md) and [Hybrid Playback ADR](../../docs/adr/ADR-008-hybrid-playback.md) for current limits and direction.
