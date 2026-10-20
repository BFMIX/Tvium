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
}
