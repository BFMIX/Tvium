import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/library/source_refresh_schedule.dart';
import 'package:tvium_app/features/xtream/secure_xtream_profile_store.dart';

final class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  test('refresh timing is independent for each source', () async {
    var now = DateTime.utc(2026, 1, 1);
    final schedule = SourceRefreshSchedule(
      store: _MemoryStore(),
      now: () => now,
    );
    await schedule.setInterval('source-a', SourceRefreshInterval.sixHours);
    await schedule.setInterval('source-b', SourceRefreshInterval.manual);
    expect(await schedule.isDue('source-a'), isFalse);
    expect(await schedule.isDue('source-b'), isFalse);
    now = now.add(const Duration(hours: 5));
    expect(await schedule.isDue('source-a'), isFalse);
    now = now.add(const Duration(hours: 1));
    expect(await schedule.isDue('source-a'), isTrue);
  });

  test('clock rollback restarts the source refresh interval', () async {
    var now = DateTime.utc(2026, 1, 2);
    final schedule = SourceRefreshSchedule(
      store: _MemoryStore(),
      now: () => now,
    );
    await schedule.setInterval('source-a', SourceRefreshInterval.sixHours);
    expect(await schedule.isDue('source-a'), isFalse);

    now = DateTime.utc(2026, 1, 1);
    expect(await schedule.isDue('source-a'), isFalse);
    now = now.add(const Duration(hours: 6));
    expect(await schedule.isDue('source-a'), isTrue);
  });

  test('runner refreshes due sources once while the app stays open', () async {
    var now = DateTime.utc(2026, 1, 1);
    final schedule = SourceRefreshSchedule(
      store: _MemoryStore(),
      now: () => now,
    );
    await schedule.setInterval('source-a', SourceRefreshInterval.sixHours);
    await schedule.setInterval('source-b', SourceRefreshInterval.manual);
    final runner = SourceRefreshRunner(schedule);
    final refreshed = <String>[];
    Future<void> refresh(String id) async => refreshed.add(id);

    await runner.check(['source-a', 'source-b'], refresh);
    now = now.add(const Duration(hours: 6));
    await runner.check(['source-a', 'source-b'], refresh);
    await runner.check(['source-a', 'source-b'], refresh);
    expect(refreshed, ['source-a']);
  });

  test('runner does not overlap active checks', () async {
    var now = DateTime.utc(2026, 1, 1);
    final schedule = SourceRefreshSchedule(
      store: _MemoryStore(),
      now: () => now,
    );
    await schedule.setInterval('source-a', SourceRefreshInterval.sixHours);
    final runner = SourceRefreshRunner(schedule);
    await runner.check(['source-a'], (_) async {});
    now = now.add(const Duration(hours: 6));
    final release = Completer<void>();
    var calls = 0;
    final first = runner.check(['source-a'], (_) async {
      calls++;
      await release.future;
    });
    await Future<void>.delayed(Duration.zero);
    await runner.check(['source-a'], (_) async => calls++);
    release.complete();
    await first;
    expect(calls, 1);
  });

  test('one source refresh failure does not skip another due source', () async {
    var now = DateTime.utc(2026, 1, 1);
    final schedule = SourceRefreshSchedule(
      store: _MemoryStore(),
      now: () => now,
    );
    for (final id in ['source-a', 'source-b']) {
      await schedule.setInterval(id, SourceRefreshInterval.sixHours);
    }
    final runner = SourceRefreshRunner(schedule);
    await runner.check(['source-a', 'source-b'], (_) async {});
    now = now.add(const Duration(hours: 6));
    final refreshed = <String>[];
    await runner.check(['source-a', 'source-b'], (id) async {
      refreshed.add(id);
      if (id == 'source-a') throw StateError('Synthetic failure');
    });
    expect(refreshed, ['source-a', 'source-b']);
  });
}
