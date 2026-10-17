import 'package:tvium_epg/tvium_epg.dart';

final class EpgChannelLink {
  const EpgChannelLink({
    required this.appChannelId,
    required this.epgSourceId,
    required this.xmltvChannelId,
    required this.strategy,
  });

  final String appChannelId;
  final String epgSourceId;
  final String xmltvChannelId;
  final EpgMatchStrategy strategy;
}

final class EpgNowNext {
  const EpgNowNext({this.current, this.next});

  final EpgProgramme? current;
  final EpgProgramme? next;
}

abstract interface class EpgRepository {
  Future<void> replaceEpg({
    required String epgSourceId,
    required Iterable<EpgChannel> channels,
    required Iterable<EpgProgramme> programmes,
    required Iterable<EpgChannelLink> links,
  });

  Future<EpgNowNext> nowNextForChannel(String appChannelId, DateTime atUtc);

  Future<List<EpgProgramme>> searchProgrammes({
    required String query,
    required DateTime fromUtc,
    required DateTime toUtc,
    int limit = 50,
  });

  Future<int> pruneEpgBefore(DateTime cutoffUtc);
}
