import 'dart:collection';

import 'package:tvium_core/tvium_core.dart';

/// One source-preserving item emitted by an M3U import.
final class M3uEntry {
  M3uEntry({
    required this.id,
    required this.originalExtInf,
    required this.originalName,
    required this.originalUri,
    required Map<String, String> attributes,
    required this.kind,
  }) : attributes = UnmodifiableMapView<String, String>(attributes);

  final String id;
  final String originalExtInf;
  final String originalName;
  final Uri originalUri;
  final Map<String, String> attributes;
  final MediaKind kind;

  String? get groupTitle => attributes['group-title'];
  Uri? get logoUri {
    final value = attributes['tvg-logo']?.trim();
    return value == null || value.isEmpty ? null : Uri.tryParse(value);
  }
}
