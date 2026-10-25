import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../xtream/secure_xtream_profile_store.dart';

final sourceRefreshScheduleProvider = Provider<SourceRefreshSchedule>(
  (ref) => SourceRefreshSchedule(),
);

enum SourceRefreshInterval {
  manual(null, 'Manual'),
  sixHours(Duration(hours: 6), 'Every 6 hours'),
  daily(Duration(days: 1), 'Daily'),
  weekly(Duration(days: 7), 'Weekly');

  const SourceRefreshInterval(this.duration, this.label);

  final Duration? duration;
  final String label;
}

final class SourceRefreshHealth {
  const SourceRefreshHealth({
    required this.lastAttempt,
    required this.lastSuccess,
    required this.lastAttemptFailed,
    required this.nextCheck,
  });

  final DateTime? lastAttempt;
  final DateTime? lastSuccess;
  final bool lastAttemptFailed;
  final DateTime? nextCheck;
}

/// Stores only an opaque source ID and timestamps, never playlist details.
final class SourceRefreshSchedule {
  SourceRefreshSchedule({SecureKeyValueStore? store, DateTime Function()? now})
    : _store =
          store ??
          FlutterSecureKeyValueStore(
            storage: const FlutterSecureStorage(
              webOptions: WebOptions(useSessionStorage: false),
              mOptions: MacOsOptions(usesDataProtectionKeychain: false),
            ),
          ),
      _now = now ?? DateTime.now;

  final SecureKeyValueStore _store;
  final DateTime Function() _now;
  static final _validId = RegExp(r'^[A-Za-z0-9_-]+$');

  String _key(String sourceId, String suffix) {
    if (!_validId.hasMatch(sourceId)) {
      throw ArgumentError('Invalid source ID.');
    }
    return 'tvium.source.refresh.$sourceId.$suffix';
  }

  Future<SourceRefreshInterval> intervalFor(String sourceId) async {
    final stored = await _store.read(_key(sourceId, 'interval'));
    return SourceRefreshInterval.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => SourceRefreshInterval.daily,
    );
  }

  Future<void> setInterval(String sourceId, SourceRefreshInterval interval) =>
      _store.write(_key(sourceId, 'interval'), interval.name);

  Future<bool> isDue(String sourceId) async {
    final interval = await intervalFor(sourceId);
    final duration = interval.duration;
    if (duration == null) return false;
    final lastValue = await _store.read(_key(sourceId, 'attempt'));
    final last = lastValue == null ? null : DateTime.tryParse(lastValue);
    final now = _now().toUtc();
    if (last == null || last.isAfter(now)) {
      await markAttempt(sourceId);
      return false;
    }
    return !now.isBefore(last.add(duration));
  }

  Future<void> markAttempt(String sourceId) =>
      _store.write(_key(sourceId, 'attempt'), _now().toUtc().toIso8601String());

  Future<DateTime?> lastAttemptFor(String sourceId) async {
    final stored = await _store.read(_key(sourceId, 'attempt'));
    return stored == null ? null : DateTime.tryParse(stored)?.toUtc();
  }

  Future<void> recordSuccess(String sourceId) async {
    final at = _now().toUtc().toIso8601String();
    await _store.write(_key(sourceId, 'attempt'), at);
    await _store.write(_key(sourceId, 'success'), at);
    await _store.write(_key(sourceId, 'outcome'), 'success');
  }

  Future<void> recordFailure(String sourceId) async {
    await markAttempt(sourceId);
    await _store.write(_key(sourceId, 'outcome'), 'failure');
  }

  Future<SourceRefreshHealth> healthFor(String sourceId) async {
    final interval = await intervalFor(sourceId);
    final attempt = await lastAttemptFor(sourceId);
    final savedSuccess = await _store.read(_key(sourceId, 'success'));
    final success = savedSuccess == null
        ? null
        : DateTime.tryParse(savedSuccess)?.toUtc();
    final outcome = await _store.read(_key(sourceId, 'outcome'));
    final duration = interval.duration;
    final now = _now().toUtc();
    final nextCheck = duration == null || attempt == null
        ? null
        : (attempt.isAfter(now) ? now : attempt).add(duration);
    return SourceRefreshHealth(
      lastAttempt: attempt,
      lastSuccess: success,
      lastAttemptFailed: outcome == 'failure',
      nextCheck: nextCheck,
    );
  }

  Future<void> remove(String sourceId) async {
    await _store.delete(_key(sourceId, 'interval'));
    await _store.delete(_key(sourceId, 'attempt'));
    await _store.delete(_key(sourceId, 'success'));
    await _store.delete(_key(sourceId, 'outcome'));
  }
}

/// Runs due checks serially while keeping failures scoped to one source.
final class SourceRefreshRunner {
  SourceRefreshRunner(this._schedule);

  final SourceRefreshSchedule _schedule;
  var _running = false;

  Future<void> check(
    Iterable<String> sourceIds,
    Future<void> Function(String sourceId) refresh,
  ) async {
    if (_running) return;
    _running = true;
    try {
      for (final sourceId in sourceIds) {
        try {
          if (!await _schedule.isDue(sourceId)) continue;
          await _schedule.markAttempt(sourceId);
          await refresh(sourceId);
        } on Object {
          // A failure never removes the cached catalog or stops other sources.
        }
      }
    } finally {
      _running = false;
    }
  }
}
