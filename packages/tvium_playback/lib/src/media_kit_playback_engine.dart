import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:media_kit_video/media_kit_video.dart';

import 'media_source.dart';
import 'playback_engine.dart';
import 'playback_state.dart';
import 'playback_state_machine.dart';

final class MediaKitPlaybackEngine implements PlaybackEngine {
  MediaKitPlaybackEngine() {
    media_kit.MediaKit.ensureInitialized();
    _player = media_kit.Player();
    _videoController = VideoController(_player);
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _player.stream.playing.listen((playing) {
        if (playing) {
          _machine.markPlaying();
        } else if (_machine.current.phase == PlaybackPhase.playing) {
          _machine.markPaused();
        }
      }),
      _player.stream.buffering.listen((buffering) {
        if (buffering) {
          _machine.markBuffering();
        }
      }),
      _player.stream.position.listen(_machine.markPosition),
      _player.stream.duration.listen(_machine.markDuration),
      _player.stream.completed.listen((completed) {
        if (completed) {
          _machine.markEnded();
        }
      }),
      _player.stream.error.listen(_machine.markFailed),
    ]);
  }

  late final media_kit.Player _player;
  late final VideoController _videoController;
  final PlaybackStateMachine _machine = PlaybackStateMachine();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  @override
  PlaybackState get currentState => _machine.current;

  @override
  Stream<PlaybackState> get state => _machine.states;

  @override
  Future<void> open(MediaSource source) async {
    _machine.markOpening();
    try {
      await _player.open(
        media_kit.Media(
          source.uri.toString(),
          httpHeaders: source.headers.isEmpty ? null : source.headers,
        ),
        play: false,
      );
      _machine.markReady(duration: _player.state.duration);
    } on Object catch (error) {
      _machine.markFailed('Unable to open ${source.uri}: $error');
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _machine.markStopped();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0, 1) * 100);

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _player.setRate(speed.clamp(0.25, 4));

  @override
  Future<void> selectAudioTrack(String id) async {
    final track = _player.state.tracks.audio
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (track == null) {
      _machine.markFailed('Requested audio track is unavailable');
      return;
    }
    await _player.setAudioTrack(track);
  }

  @override
  Future<void> selectSubtitleTrack(String id) async {
    final track = _player.state.tracks.subtitle
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (track == null) {
      _machine.markFailed('Requested subtitle track is unavailable');
      return;
    }
    await _player.setSubtitleTrack(track);
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _machine.dispose();
  }
}

final class MediaKitPlaybackView extends StatelessWidget {
  const MediaKitPlaybackView({
    required this.engine,
    this.fit = BoxFit.contain,
    super.key,
  });

  final MediaKitPlaybackEngine engine;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Video(controller: engine._videoController, fit: fit, controls: null);
  }
}
