import 'persisted_media_entry.dart';

final class PlaylistEntryChange {
  const PlaylistEntryChange({required this.before, required this.after});

  final PersistedMediaEntry before;
  final PersistedMediaEntry after;
}

final class PlaylistDiff {
  PlaylistDiff._({
    required Iterable<PersistedMediaEntry> added,
    required Iterable<PlaylistEntryChange> changed,
    required Iterable<PersistedMediaEntry> removed,
    required Iterable<PersistedMediaEntry> unchanged,
  }) : added = List<PersistedMediaEntry>.unmodifiable(added),
       changed = List<PlaylistEntryChange>.unmodifiable(changed),
       removed = List<PersistedMediaEntry>.unmodifiable(removed),
       unchanged = List<PersistedMediaEntry>.unmodifiable(unchanged);

  factory PlaylistDiff.calculate({
    required Iterable<PersistedMediaEntry> previous,
    required Iterable<PersistedMediaEntry> incoming,
  }) {
    final previousList = previous.toList(growable: false);
    final incomingList = incoming.toList(growable: false);
    final previousByIdentity = _index(previousList, 'previous');
    final incomingByIdentity = _index(incomingList, 'incoming');
    final added = <PersistedMediaEntry>[];
    final changed = <PlaylistEntryChange>[];
    final unchanged = <PersistedMediaEntry>[];

    for (final entry in incomingList) {
      final before = previousByIdentity[_identity(entry)];
      if (before == null) {
        added.add(entry);
      } else if (_sameProjection(before, entry)) {
        unchanged.add(entry);
      } else {
        changed.add(PlaylistEntryChange(before: before, after: entry));
      }
    }

    final removed = previousList
        .where((entry) => !incomingByIdentity.containsKey(_identity(entry)))
        .toList(growable: false);

    return PlaylistDiff._(
      added: added,
      changed: changed,
      removed: removed,
      unchanged: unchanged,
    );
  }

  final List<PersistedMediaEntry> added;
  final List<PlaylistEntryChange> changed;
  final List<PersistedMediaEntry> removed;
  final List<PersistedMediaEntry> unchanged;
}

Map<String, PersistedMediaEntry> _index(
  List<PersistedMediaEntry> entries,
  String argumentName,
) {
  final indexed = <String, PersistedMediaEntry>{};
  for (final entry in entries) {
    final identity = _identity(entry);
    if (indexed.containsKey(identity)) {
      throw ArgumentError.value(
        '<redacted>',
        argumentName,
        'Playlist entries must have unique identities.',
      );
    }
    indexed[identity] = entry;
  }
  return indexed;
}

String _identity(PersistedMediaEntry entry) {
  return '${entry.playlistId}\u0000${entry.id}';
}

bool _sameProjection(PersistedMediaEntry before, PersistedMediaEntry after) {
  return before.playlistId == after.playlistId &&
      before.id == after.id &&
      before.sourceReference == after.sourceReference &&
      before.originalName == after.originalName &&
      before.displayName == after.displayName &&
      before.groupName == after.groupName &&
      before.kind == after.kind;
}
