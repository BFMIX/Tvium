import 'package:flutter/foundation.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

import 'm3u_import_persistence.dart';

enum PlaylistImportPhase { empty, importing, ready, failed }

final class PlaylistImportState {
  const PlaylistImportState({
    this.phase = PlaylistImportPhase.empty,
    this.entries = const <M3uEntry>[],
    this.parsedCount = 0,
    this.warningCount = 0,
    this.groupCount = 0,
    this.message,
  });

  final PlaylistImportPhase phase;
  final List<M3uEntry> entries;
  final int parsedCount;
  final int warningCount;
  final int groupCount;
  final String? message;

  PlaylistImportState copyWith({
    PlaylistImportPhase? phase,
    List<M3uEntry>? entries,
    int? parsedCount,
    int? warningCount,
    int? groupCount,
    String? message,
  }) {
    return PlaylistImportState(
      phase: phase ?? this.phase,
      entries: entries ?? this.entries,
      parsedCount: parsedCount ?? this.parsedCount,
      warningCount: warningCount ?? this.warningCount,
      groupCount: groupCount ?? this.groupCount,
      message: message,
    );
  }
}

final class PlaylistImportController extends ChangeNotifier {
  factory PlaylistImportController({
    M3uParser parser = const M3uParser(),
    M3uImportPersistence? persistence,
  }) => PlaylistImportController._(parser, persistence);

  PlaylistImportController._(this._parser, this._persistence);

  final M3uParser _parser;
  final M3uImportPersistence? _persistence;
  PlaylistImportState _state = const PlaylistImportState();
  var _generation = 0;

  PlaylistImportState get state => _state;

  Future<void> importSource(
    M3uSource source, {
    M3uSourceDescriptor? descriptor,
  }) async {
    final generation = ++_generation;
    final entries = <M3uEntry>[];
    _setState(const PlaylistImportState(phase: PlaylistImportPhase.importing));
    try {
      await for (final event in _parser.parse(source.readLines())) {
        if (generation != _generation) {
          return;
        }
        switch (event) {
          case M3uBatch(entries: final batchEntries, :final parsedCount):
            entries.addAll(batchEntries);
            _setState(
              PlaylistImportState(
                phase: PlaylistImportPhase.importing,
                entries: List<M3uEntry>.unmodifiable(entries),
                parsedCount: parsedCount,
                warningCount: _state.warningCount,
              ),
            );
          case M3uWarning():
            _setState(_state.copyWith(warningCount: _state.warningCount + 1));
          case M3uCompleted(:final summary):
            if (descriptor != null) {
              await _persistence?.persist(descriptor, entries);
            }
            _setState(
              PlaylistImportState(
                phase: PlaylistImportPhase.ready,
                entries: List<M3uEntry>.unmodifiable(entries),
                parsedCount: summary.parsedEntries,
                warningCount: summary.warningCount,
                groupCount: summary.groupCount,
              ),
            );
        }
      }
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      final message = error is M3uSourceException
          ? error.message
          : SensitiveDataSanitizer.sanitize(error.toString());
      _setState(
        PlaylistImportState(
          phase: PlaylistImportPhase.failed,
          message: message,
        ),
      );
    }
  }

  void cancel() {
    _generation++;
    _setState(const PlaylistImportState());
  }

  void reportValidationFailure(String message) {
    _setState(
      PlaylistImportState(
        phase: PlaylistImportPhase.failed,
        message: SensitiveDataSanitizer.sanitize(message),
      ),
    );
  }

  void _setState(PlaylistImportState value) {
    _state = value;
    notifyListeners();
  }
}
