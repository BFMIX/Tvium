import 'dart:convert';
import 'dart:io';

import 'package:tvium_m3u/tvium_m3u.dart';

Future<void> main(List<String> arguments) async {
  final entryCount = _entryCount(arguments);
  final parser = const M3uParser(batchSize: 500);
  final lines = Stream<String>.fromIterable(
    const SyntheticM3uGenerator().generateLines(entryCount),
  );
  final rssBefore = ProcessInfo.currentRss;
  var maxRss = rssBefore;
  var parsedEntries = 0;
  var warnings = 0;
  final stopwatch = Stopwatch()..start();

  await for (final event in parser.parse(lines)) {
    final currentRss = ProcessInfo.currentRss;
    if (currentRss > maxRss) {
      maxRss = currentRss;
    }
    if (event case M3uCompleted(:final summary)) {
      parsedEntries = summary.parsedEntries;
      warnings = summary.warningCount;
    }
  }
  stopwatch.stop();

  final seconds =
      stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond;
  final throughput = seconds == 0 ? 0 : (parsedEntries / seconds).round();
  stdout.writeln(
    jsonEncode(<String, Object>{
      'requestedEntries': entryCount,
      'parsedEntries': parsedEntries,
      'warnings': warnings,
      'elapsedMicroseconds': stopwatch.elapsedMicroseconds,
      'entriesPerSecond': throughput,
      'rssBeforeBytes': rssBefore,
      'peakObservedRssBytes': maxRss,
      'observedRssDeltaBytes': maxRss - rssBefore,
    }),
  );
}

int _entryCount(List<String> arguments) {
  final index = arguments.indexOf('--entries');
  if (index == -1) {
    return 10000;
  }
  if (index + 1 >= arguments.length) {
    throw const FormatException('--entries requires a value');
  }
  final parsed = int.tryParse(arguments[index + 1]);
  if (parsed == null || parsed < 0) {
    throw const FormatException('--entries must be a non-negative integer');
  }
  return parsed;
}
