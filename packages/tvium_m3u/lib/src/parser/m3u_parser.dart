import 'dart:async';

import 'package:tvium_core/tvium_core.dart';

import '../model/m3u_entry.dart';
import '../model/m3u_import_event.dart';

/// Incrementally converts M3U lines into bounded batches of source entries.
final class M3uParser {
  const M3uParser({this.batchSize = 250}) : assert(batchSize > 0);

  final int batchSize;

  Stream<M3uImportEvent> parse(Stream<String> lines) async* {
    final batch = <M3uEntry>[];
    final groups = <String>{};
    _PendingEntry? pending;
    var lineNumber = 0;
    var parsedEntries = 0;
    var warningCount = 0;

    await for (final rawLine in lines) {
      lineNumber++;
      final line = rawLine.trim();
      if (line.isEmpty || line == '#EXTM3U') {
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        if (pending != null) {
          warningCount++;
          yield M3uWarning(
            lineNumber: pending.lineNumber,
            message: 'Entry has no stream URI',
          );
        }
        pending = _parseExtInf(line, lineNumber);
        continue;
      }

      if (line.startsWith('#')) {
        continue;
      }

      if (pending == null) {
        warningCount++;
        yield M3uWarning(
          lineNumber: lineNumber,
          message: 'Stream URI has no EXTINF entry',
        );
        continue;
      }

      final uri = Uri.tryParse(line);
      if (uri == null || !uri.hasScheme) {
        warningCount++;
        yield M3uWarning(
          lineNumber: lineNumber,
          message: 'Entry has an invalid stream URI',
        );
        pending = null;
        continue;
      }

      parsedEntries++;
      final entry = M3uEntry(
        id: 'entry-$parsedEntries',
        originalExtInf: pending.extInf,
        originalName: pending.name,
        originalUri: uri,
        attributes: pending.attributes,
        kind: _classify(pending.name, uri, pending.attributes),
      );
      final group = entry.groupTitle;
      if (group != null && group.isNotEmpty) {
        groups.add(group);
      }
      batch.add(entry);
      pending = null;

      if (batch.length == batchSize) {
        yield M3uBatch(
          entries: List<M3uEntry>.unmodifiable(batch),
          parsedCount: parsedEntries,
        );
        batch.clear();
      }
    }

    if (pending != null) {
      warningCount++;
      yield M3uWarning(
        lineNumber: pending.lineNumber,
        message: 'Entry has no stream URI',
      );
    }
    if (batch.isNotEmpty) {
      yield M3uBatch(
        entries: List<M3uEntry>.unmodifiable(batch),
        parsedCount: parsedEntries,
      );
    }
    yield M3uCompleted(
      M3uImportSummary(
        parsedEntries: parsedEntries,
        warningCount: warningCount,
        groupCount: groups.length,
      ),
    );
  }

  _PendingEntry _parseExtInf(String line, int lineNumber) {
    final commaIndex = _metadataCommaIndex(line);
    final metadata = commaIndex == -1 ? line : line.substring(0, commaIndex);
    final name = commaIndex == -1 ? '' : line.substring(commaIndex + 1).trim();
    final attributes = <String, String>{};
    final attributePattern = RegExp(r'([\w-]+)="([^"]*)"');
    for (final match in attributePattern.allMatches(metadata)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        attributes[key.toLowerCase()] = value;
      }
    }
    return _PendingEntry(
      extInf: line,
      name: name,
      attributes: attributes,
      lineNumber: lineNumber,
    );
  }

  int _metadataCommaIndex(String line) {
    var quoted = false;
    for (var index = 0; index < line.length; index++) {
      final character = line[index];
      if (character == '"') {
        quoted = !quoted;
      } else if (character == ',' && !quoted) {
        return index;
      }
    }
    return -1;
  }

  MediaKind _classify(String name, Uri uri, Map<String, String> attributes) {
    final episodePattern = RegExp(
      r'\b(?:S\d{1,2}\s*E\d{1,3}|\d{1,2}x\d{1,3}|'
      r'Season\s+\d+\s+Episode\s+\d+|Saison\s+\d+\s+[ÉE]pisode\s+\d+|'
      r'Temporada\s+\d+\s+Episodio\s+\d+)\b',
      caseSensitive: false,
    );
    if (episodePattern.hasMatch(name)) {
      return MediaKind.episode;
    }

    final path = uri.path.toLowerCase();
    const movieExtensions = <String>['.mp4', '.mkv', '.avi', '.mov', '.m4v'];
    if (movieExtensions.any(path.endsWith)) {
      return MediaKind.movie;
    }
    if (path.endsWith('.m3u8') ||
        attributes.containsKey('tvg-id') ||
        attributes.containsKey('tvg-chno')) {
      return MediaKind.live;
    }
    return MediaKind.unclassified;
  }
}

final class _PendingEntry {
  const _PendingEntry({
    required this.extInf,
    required this.name,
    required this.attributes,
    required this.lineNumber,
  });

  final String extInf;
  final String name;
  final Map<String, String> attributes;
  final int lineNumber;
}
