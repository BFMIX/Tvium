import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_playback/tvium_playback.dart';

void main() {
  test('maps a playback lifecycle into ordered public states', () async {
    final machine = PlaybackStateMachine();
    addTearDown(machine.dispose);
    final phases = <PlaybackPhase>[];
    final subscription = machine.states.listen(
      (state) => phases.add(state.phase),
    );
    addTearDown(subscription.cancel);

    machine
      ..markOpening()
      ..markReady(duration: const Duration(minutes: 42))
      ..markPlaying()
      ..markBuffering()
      ..markPaused(position: const Duration(minutes: 3))
      ..markStopped();
    await Future<void>.delayed(Duration.zero);

    expect(phases, <PlaybackPhase>[
      PlaybackPhase.opening,
      PlaybackPhase.ready,
      PlaybackPhase.playing,
      PlaybackPhase.buffering,
      PlaybackPhase.paused,
      PlaybackPhase.idle,
    ]);
    expect(machine.current.position, Duration.zero);
  });

  test('publishes a sanitized failure without leaking its source', () async {
    final machine = PlaybackStateMachine();
    addTearDown(machine.dispose);

    machine.markFailed(
      'Could not open https://alice:secret@stream.example.test/live/'
      'alice/secret/index.m3u8?token=abc',
    );

    expect(machine.current.phase, PlaybackPhase.failed);
    expect(machine.current.failure?.message, contains('stream.example.test'));
    expect(machine.current.failure?.message, isNot(contains('alice')));
    expect(machine.current.failure?.message, isNot(contains('secret')));
    expect(machine.current.failure?.message, isNot(contains('abc')));
  });

  test('media source debug labels never expose stream URLs', () {
    final source = MediaSource(
      uri: Uri.parse('https://user:pass@example.test/live/token/index.m3u8'),
      title: 'Demo',
    );

    expect(
      source.toString(),
      'MediaSource(title: Demo, uri: https://example.test/***)',
    );
  });
}
