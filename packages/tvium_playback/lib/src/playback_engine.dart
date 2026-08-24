import 'media_source.dart';
import 'playback_state.dart';

abstract interface class PlaybackEngine {
  Stream<PlaybackState> get state;
  PlaybackState get currentState;

  Future<void> open(MediaSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> selectAudioTrack(String id);
  Future<void> selectSubtitleTrack(String id);
  Future<void> dispose();
}
