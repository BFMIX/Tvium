import 'm3u_entry.dart';

sealed class M3uImportEvent {
  const M3uImportEvent();
}

final class M3uBatch extends M3uImportEvent {
  const M3uBatch({required this.entries, required this.parsedCount});

  final List<M3uEntry> entries;
  final int parsedCount;
}

final class M3uWarning extends M3uImportEvent {
  const M3uWarning({required this.lineNumber, required this.message});

  final int lineNumber;
  final String message;
}

final class M3uCompleted extends M3uImportEvent {
  const M3uCompleted(this.summary);

  final M3uImportSummary summary;
}

final class M3uImportSummary {
  const M3uImportSummary({
    required this.parsedEntries,
    required this.warningCount,
    required this.groupCount,
  });

  final int parsedEntries;
  final int warningCount;
  final int groupCount;
}
