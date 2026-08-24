import 'package:tvium_core/tvium_core.dart';

/// Searchable, non-secret projection of one imported source entry.
final class PersistedMediaEntry {
  const PersistedMediaEntry({
    required this.id,
    required this.playlistId,
    required this.sourceReference,
    required this.originalName,
    required this.displayName,
    required this.groupName,
    required this.kind,
  });

  final String id;
  final String playlistId;

  /// Opaque key for credentials or stream details held outside indexed rows.
  final String sourceReference;

  final String originalName;
  final String displayName;
  final String? groupName;
  final MediaKind kind;
}
