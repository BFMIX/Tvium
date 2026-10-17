import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_epg/tvium_epg.dart';

import 'epg_source.dart';

enum EpgImportPhase { idle, importing, ready, failed }

final class EpgImportState {
  const EpgImportState({
    this.phase = EpgImportPhase.idle,
    this.channelCount = 0,
    this.programmeCount = 0,
    this.matchedChannelCount = 0,
    this.message,
  });

  final EpgImportPhase phase;
  final int channelCount;
  final int programmeCount;
  final int matchedChannelCount;
  final String? message;

  @override
  String toString() =>
      'EpgImportState($phase, channels: $channelCount, programmes: '
      '$programmeCount, matched: $matchedChannelCount, message: $message)';
}

final class EpgImportController {
  EpgImportController({
    required this.epgRepository,
    required this.libraryRepository,
    XmltvParser? parser,
    EpgChannelMatcher? matcher,
  }) : _parser = parser ?? XmltvParser(),
       _matcher = matcher ?? EpgChannelMatcher();

  final EpgRepository epgRepository;
  final ProfileSourceRepository libraryRepository;
  final XmltvParser _parser;
  final EpgChannelMatcher _matcher;

  EpgImportState state = const EpgImportState();

  Future<void> importSource(
    EpgSource source, {
    Iterable<PersistedMediaEntry> additionalEntries = const [],
  }) async {
    state = const EpgImportState(phase: EpgImportPhase.importing);
    try {
      final parsed = await _parser.parse(source.readBytes());
      final profile = await libraryRepository.activeProfile();
      final sources = await libraryRepository.sourcesForProfile(profile.id);
      final entries = <PersistedMediaEntry>[];
      for (final librarySource in sources) {
        entries.addAll(
          await libraryRepository.entriesForPlaylist(librarySource.id),
        );
      }
      entries.addAll(additionalEntries);

      final links = <EpgChannelLink>[];
      for (final entry in entries) {
        if (entry.kind != MediaKind.live) continue;
        final match = _matcher.match(
          EpgChannelCandidate(
            appChannelId: entry.id,
            displayName: entry.displayName,
            tvgId: entry.epgChannelId,
          ),
          parsed.channels,
        );
        if (match == null) continue;
        links.add(
          EpgChannelLink(
            appChannelId: entry.id,
            epgSourceId: source.sourceId,
            xmltvChannelId: match.channelId,
            strategy: match.strategy,
          ),
        );
      }

      await epgRepository.replaceEpg(
        epgSourceId: source.sourceId,
        channels: parsed.channels,
        programmes: parsed.programmes,
        links: links,
      );
      state = EpgImportState(
        phase: EpgImportPhase.ready,
        channelCount: parsed.channels.length,
        programmeCount: parsed.programmes.length,
        matchedChannelCount: links.length,
        message: 'Programme guide imported.',
      );
    } catch (_) {
      state = const EpgImportState(
        phase: EpgImportPhase.failed,
        message: 'The programme guide could not be imported.',
      );
    }
  }
}
