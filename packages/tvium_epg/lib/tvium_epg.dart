/// Offline XMLTV parsing and deterministic channel matching.
library;

import 'dart:convert';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

class EpgChannel {
  const EpgChannel({required this.id, required this.displayName, this.iconUri});
  final String id;
  final String displayName;
  final Uri? iconUri;
}

class EpgProgramme {
  EpgProgramme({
    required this.channelId,
    required DateTime startUtc,
    required DateTime stopUtc,
    required this.title,
    this.subtitle,
    this.description,
    List<String> categories = const [],
  }) : startUtc = startUtc.toUtc(),
       stopUtc = stopUtc.toUtc(),
       categories = List.unmodifiable(categories);
  final String channelId;
  final DateTime startUtc;
  final DateTime stopUtc;
  final String title;
  final String? subtitle;
  final String? description;
  final List<String> categories;
}

class EpgImportResult {
  EpgImportResult({
    required List<EpgChannel> channels,
    required List<EpgProgramme> programmes,
    required List<String> warnings,
  }) : channels = List.unmodifiable(channels),
       programmes = List.unmodifiable(programmes),
       warnings = List.unmodifiable(warnings);
  final List<EpgChannel> channels;
  final List<EpgProgramme> programmes;
  final List<String> warnings;
}

class XmltvParser {
  /// Parses incrementally, retaining only output records and the current record.
  /// Invalid programme records are skipped; malformed/unsafe XML fails closed.
  Future<EpgImportResult> parse(Stream<List<int>> bytes) async {
    final builder = _ImportBuilder();
    try {
      final events = bytes
          .transform(utf8.decoder)
          .transform(
            XmlEventDecoder(
              entityMapping: const XmlNullEntityMapping(),
              validateDocument: true,
              validateNesting: true,
            ),
          )
          .normalizeEvents();
      await for (final batch in events) {
        for (final event in batch) {
          builder.add(event);
        }
      }
      return builder.result();
    } on XmlException {
      // Parser exceptions may retain source fragments; never expose them.
      throw const FormatException('Invalid XMLTV document.');
    } on FormatException {
      throw const FormatException('Invalid or unsupported XMLTV document.');
    }
  }
}

class EpgChannelCandidate {
  const EpgChannelCandidate({
    required this.appChannelId,
    required this.displayName,
    this.tvgId,
  });
  final String appChannelId;
  final String displayName;
  final String? tvgId;
}

enum EpgMatchStrategy { exactId, explicit, normalizedName }

class EpgChannelMatch {
  const EpgChannelMatch({required this.channelId, required this.strategy});
  final String channelId;
  final EpgMatchStrategy strategy;
}

class EpgChannelMatcher {
  /// Exact IDs precede explicit mappings, then a unique normalized name.
  /// Ambiguous names never select an arbitrary first channel.
  EpgChannelMatch? match(
    EpgChannelCandidate candidate,
    Iterable<EpgChannel> channels, {
    Map<String, String> explicitMappings = const {},
  }) {
    final available = channels.toList(growable: false);
    final exactId = candidate.tvgId;
    if (exactId != null && exactId.isNotEmpty) {
      final exact = available
          .where((channel) => channel.id == exactId)
          .toList();
      if (exact.length == 1) {
        return EpgChannelMatch(
          channelId: exact.single.id,
          strategy: EpgMatchStrategy.exactId,
        );
      }
      if (exact.length > 1) return null;
    }
    final mappedId = explicitMappings[candidate.appChannelId];
    if (mappedId != null) {
      final explicit = available
          .where((channel) => channel.id == mappedId)
          .toList();
      if (explicit.length == 1) {
        return EpgChannelMatch(
          channelId: explicit.single.id,
          strategy: EpgMatchStrategy.explicit,
        );
      }
      // A stale explicit mapping is not silently replaced with a name guess.
      return null;
    }
    final name = _normalizedName(candidate.displayName);
    if (name.isEmpty) return null;
    final named = available
        .where((channel) => _normalizedName(channel.displayName) == name)
        .toList();
    return named.length == 1
        ? EpgChannelMatch(
            channelId: named.single.id,
            strategy: EpgMatchStrategy.normalizedName,
          )
        : null;
  }
}

String _normalizedName(String value) => value.toLowerCase().replaceAll(
  RegExp(r'[^\p{L}\p{N}+]', unicode: true),
  '',
);

class _ImportBuilder {
  final _channels = <EpgChannel>[];
  final _programmes = <EpgProgramme>[];
  final _warnings = <String>[];
  final _stack = <String>[];
  _Record? _record;
  StringBuffer? _field;
  bool _sawRoot = false;

  void add(XmlEvent event) {
    if (event is XmlDoctypeEvent) {
      throw const FormatException('DOCTYPE is not supported.');
    } else if (event is XmlStartElementEvent) {
      final attributes = <String, String>{
        for (final attribute in event.attributes)
          attribute.name: _decodeText(attribute.value),
      };
      _stack.add(event.name);
      if (_stack.length == 1) {
        if (_sawRoot || event.name != 'tv') {
          throw const FormatException('Expected one XMLTV root.');
        }
        _sawRoot = true;
      } else if (_stack.length == 2 &&
          (event.name == 'channel' || event.name == 'programme')) {
        _record = _Record(event.name, attributes);
      } else if (_stack.length == 3 && _record != null) {
        _field = StringBuffer();
        if (event.name == 'icon') _record!.icon = attributes['src'];
      }
      if (event.isSelfClosing) _end();
    } else if (event is XmlEndElementEvent) {
      _end();
    } else if (event is XmlTextEvent) {
      final text = _decodeText(event.value);
      _field?.write(text);
    } else if (event is XmlCDATAEvent) {
      _field?.write(event.value);
    }
  }

  void _end() {
    if (_stack.length == 3 && _record != null) {
      final value = _field?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        (_record!.fields[_stack.last] ??= []).add(value);
      }
      _field = null;
    } else if (_stack.length == 2 && _record != null) {
      final record = _record!;
      if (record.kind == 'channel') {
        final id = record.attributes['id']?.trim();
        final name = record.first('display-name');
        if (id != null && id.isNotEmpty && name != null) {
          _channels.add(
            EpgChannel(
              id: id,
              displayName: name,
              iconUri: record.icon == null ? null : Uri.tryParse(record.icon!),
            ),
          );
        } else {
          _warnings.add('Skipped invalid channel.');
        }
      } else {
        final channelId = record.attributes['channel']?.trim();
        final start = _timestamp(record.attributes['start']);
        final stop = _timestamp(record.attributes['stop']);
        final title = record.first('title');
        if (channelId == null ||
            channelId.isEmpty ||
            start == null ||
            stop == null ||
            !stop.isAfter(start) ||
            title == null) {
          _warnings.add('Skipped invalid programme.');
        } else {
          _programmes.add(
            EpgProgramme(
              channelId: channelId,
              startUtc: start,
              stopUtc: stop,
              title: title,
              subtitle: record.first('sub-title'),
              description: record.first('desc'),
              categories: record.fields['category'] ?? const [],
            ),
          );
        }
      }
      _record = null;
    }
    _stack.removeLast();
  }

  EpgImportResult result() {
    if (!_sawRoot || _stack.isNotEmpty) {
      throw const FormatException('Incomplete XMLTV document.');
    }
    return EpgImportResult(
      channels: _channels,
      programmes: _programmes,
      warnings: _warnings,
    );
  }
}

class _Record {
  _Record(this.kind, this.attributes);
  final String kind;
  final Map<String, String> attributes;
  final fields = <String, List<String>>{};
  String? icon;

  String? first(String name) => fields[name]?.first;
}

// The event decoder never expands entities. Decode only XML's five built-ins
// and valid scalar character references here, after adjacent chunks are joined.
String _decodeText(String text) {
  const mapping = XmlDefaultEntityMapping.xml();
  final output = StringBuffer();
  var position = 0;
  while (position < text.length) {
    final start = text.indexOf('&', position);
    if (start == -1) {
      output.write(text.substring(position));
      break;
    }
    output.write(text.substring(position, start));
    final end = text.indexOf(';', start + 1);
    if (end == -1) throw const FormatException('Invalid XML reference.');
    final decoded = mapping.decodeEntity(text.substring(start + 1, end));
    if (decoded == null ||
        decoded.runes.any((rune) => !_isXmlCharacter(rune))) {
      throw const FormatException('Unsupported XML reference.');
    }
    output.write(decoded);
    position = end + 1;
  }
  return output.toString();
}

bool _isXmlCharacter(int value) =>
    value == 9 ||
    value == 10 ||
    value == 13 ||
    (value >= 0x20 && value <= 0xd7ff) ||
    (value >= 0xe000 && value <= 0xfffd) ||
    (value >= 0x10000 && value <= 0x10ffff);

DateTime? _timestamp(String? raw) {
  if (raw == null) return null;
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s+([+-])(\d{2})(\d{2}))?$',
  ).firstMatch(raw.trim());
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final date = DateTime.utc(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  if (date.year != parts[0] ||
      date.month != parts[1] ||
      date.day != parts[2] ||
      date.hour != parts[3] ||
      date.minute != parts[4] ||
      date.second != parts[5]) {
    return null;
  }
  final hours = int.parse(match.group(8) ?? '0');
  final minutes = int.parse(match.group(9) ?? '0');
  if (hours > 23 || minutes > 59) return null;
  final offset = Duration(
    minutes: (hours * 60 + minutes) * (match.group(7) == '-' ? -1 : 1),
  );
  return date.subtract(offset);
}
