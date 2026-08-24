enum PlaybackPhase {
  idle,
  opening,
  ready,
  playing,
  paused,
  buffering,
  ended,
  failed,
}

final class PlaybackFailure {
  const PlaybackFailure(this.message);

  final String message;
}

final class PlaybackState {
  const PlaybackState({
    this.phase = PlaybackPhase.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.failure,
  });

  final PlaybackPhase phase;
  final Duration position;
  final Duration duration;
  final PlaybackFailure? failure;

  PlaybackState copyWith({
    PlaybackPhase? phase,
    Duration? position,
    Duration? duration,
    PlaybackFailure? failure,
    bool clearFailure = false,
  }) {
    return PlaybackState(
      phase: phase ?? this.phase,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}
