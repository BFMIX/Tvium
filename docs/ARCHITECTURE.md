# Architecture

## Shape

Tvium is a Melos-managed Dart workspace. `apps/tvium_app` is the composition root. Feature packages expose narrow APIs:

```text
tvium_app
├── tvium_design_system
├── tvium_m3u ───────┐
├── tvium_database ──┼── tvium_core
└── tvium_playback ──┘
```

`tvium_core` has no Flutter dependency. UI code may depend on package APIs; packages never depend on the app. A widget cannot parse playlists, issue source requests, write storage, or call a video plugin directly.

## Data flow

```text
M3U source → byte/line stream → parser → raw entry → normalized media model
           → batched import events → repository boundary → virtualized UI
                                                    └──→ PlaybackEngine
```

Parsing is progressive and cancellable between batches. Original fields are immutable. Normalized and display fields are derived projections. Bad entries produce typed, sanitized warnings without failing the complete import.

## Application composition

Riverpod owns dependency injection and asynchronous view state. `go_router` owns route parsing, navigation, and future deep links. Localization resources own visible copy. Screen widgets render explicit loading, content, empty, and recoverable-error states.

## Platform boundaries

`PlaybackEngine` prevents plugin types from escaping playback packages. The Phase 0 media_kit adapter is evidence for the prototype, not the final platform strategy. Android Media3, Apple AVFoundation/AVPlayer, Windows engine selection, and Web HTML5/HLS behavior receive separate adapters after spikes.

Local persistence follows repository contracts. Drift/SQLite is the intended native implementation; Web storage requires a separate security and capacity decision. Secure-storage adapters hold credentials, while indexed library rows store opaque source references.

## Dependency rules

- Domain models are immutable and serializable without Flutter types.
- Failures cross boundaries as typed values, never raw plugin/network exceptions.
- Logging accepts only sanitized values.
- External metadata enriches but never replaces source truth.
- Background work returns batches rather than sharing mutable collections.
