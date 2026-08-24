import 'dart:async';

import 'package:tvium_core/tvium_core.dart';

import 'playback_state.dart';

final class PlaybackStateMachine {
  final StreamController<PlaybackState> _controller =
      StreamController<PlaybackState>.broadcast(sync: true);
  PlaybackState _current = const PlaybackState();

  PlaybackState get current => _current;
  Stream<PlaybackState> get states => _controller.stream;

  void markOpening() => _emit(
    _current.copyWith(
      phase: PlaybackPhase.opening,
      position: Duration.zero,
      duration: Duration.zero,
      clearFailure: true,
    ),
  );

  void markReady({required Duration duration}) => _emit(
    _current.copyWith(
      phase: PlaybackPhase.ready,
      duration: duration,
      clearFailure: true,
    ),
  );

  void markPlaying() => _emit(_current.copyWith(phase: PlaybackPhase.playing));

  void markPaused({Duration? position}) =>
      _emit(_current.copyWith(phase: PlaybackPhase.paused, position: position));

  void markBuffering() =>
      _emit(_current.copyWith(phase: PlaybackPhase.buffering));

  void markEnded() => _emit(_current.copyWith(phase: PlaybackPhase.ended));

  void markPosition(Duration position) =>
      _emit(_current.copyWith(position: position));

  void markDuration(Duration duration) =>
      _emit(_current.copyWith(duration: duration));

  void markStopped() => _emit(const PlaybackState());

  void markFailed(String message) => _emit(
    _current.copyWith(
      phase: PlaybackPhase.failed,
      failure: PlaybackFailure(SensitiveDataSanitizer.sanitize(message)),
    ),
  );

  Future<void> dispose() => _controller.close();

  void _emit(PlaybackState state) {
    if (_controller.isClosed) {
      return;
    }
    _current = state;
    _controller.add(state);
  }
}
