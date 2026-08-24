import 'dart:io';

import 'package:tvium_m3u/tvium_m3u.dart';

Future<void> main(List<String> arguments) async {
  final entryCount = _integerOption(arguments, '--entries', fallback: 10000);
  final outputPath = _stringOption(
    arguments,
    '--output',
    fallback: 'test/fixtures/generated/synthetic-$entryCount.m3u',
  );
  final output = File(outputPath);
  await output.parent.create(recursive: true);
  final sink = output.openWrite();
  try {
    for (final line in const SyntheticM3uGenerator().generateLines(
      entryCount,
    )) {
      sink.writeln(line);
    }
  } finally {
    await sink.close();
  }
  stdout.writeln('Generated $entryCount fictional entries at $outputPath');
}

int _integerOption(
  List<String> arguments,
  String name, {
  required int fallback,
}) {
  final value = _stringOption(arguments, name, fallback: '$fallback');
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw FormatException('$name must be a non-negative integer');
  }
  return parsed;
}

String _stringOption(
  List<String> arguments,
  String name, {
  required String fallback,
}) {
  final index = arguments.indexOf(name);
  if (index == -1) {
    return fallback;
  }
  if (index + 1 >= arguments.length) {
    throw FormatException('$name requires a value');
  }
  return arguments[index + 1];
}
