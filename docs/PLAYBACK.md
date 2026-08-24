# Playback

## Contract

The UI depends on `PlaybackEngine`, not on media_kit, Media3, AVPlayer, libmpv, libVLC, or browser APIs. The contract covers open, play, pause, stop, seek, volume, speed, audio/subtitle selection, lifecycle disposal, and a typed state stream.

State communicates idle, loading, ready, playing, paused, buffering, ended, and failed phases plus known duration/position, declared and observed media properties, available tracks, and sanitized errors.

## Phase 0 spike

media_kit is the provisional adapter used to exercise HLS on locally available targets. Its types remain package-private. This choice validates API shape and build integration only; it does not supersede the planned platform spikes.

## Platform direction

- Android/TV: evaluate Media3/ExoPlayer lifecycle, codec reporting, audio/subtitle tracks, zapping, and remote keys.
- Apple platforms/tvOS: evaluate AVPlayer/AVFoundation, focus/remote controls, and native HLS.
- Windows: compare libmpv and libVLC packaging, codec breadth, hardware decoding, and license implications.
- Web: native HTML video/Safari HLS and HLS.js fallback where justified; CORS and mixed content remain browser policy.

## Reliability

Retries are finite with backoff and cancellation. A stream failure may offer Retry or a high-confidence backup variant; it never creates an infinite reconnect loop or scans all variants. Diagnostics may expose engine, codec, resolution, bitrate, buffer, dropped frames, and state, but never the complete stream URI.

Compatibility claims distinguish container, codec, protocol, engine, OS, and device. MKV/AVI support is conditional and never promised globally.
