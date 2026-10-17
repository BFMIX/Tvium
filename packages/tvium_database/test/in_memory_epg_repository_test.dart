import 'package:test/test.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_epg/tvium_epg.dart';

void main() {
  test(
    'session repository provides Now and Next without durable storage',
    () async {
      final repository = InMemoryProfileSourceRepository();
      expect(repository, isA<EpgRepository>());
      final epgRepository = repository as EpgRepository;
      final now = DateTime.utc(2026, 10, 17, 12, 30);

      await epgRepository.replaceEpg(
        epgSourceId: 'guide.test',
        channels: const [EpgChannel(id: 'news.test', displayName: 'News')],
        programmes: [
          EpgProgramme(
            channelId: 'news.test',
            startUtc: DateTime.utc(2026, 10, 17, 12),
            stopUtc: DateTime.utc(2026, 10, 17, 13),
            title: 'Current',
          ),
          EpgProgramme(
            channelId: 'news.test',
            startUtc: DateTime.utc(2026, 10, 17, 13),
            stopUtc: DateTime.utc(2026, 10, 17, 14),
            title: 'Next',
          ),
        ],
        links: const [
          EpgChannelLink(
            appChannelId: 'live:news',
            epgSourceId: 'guide.test',
            xmltvChannelId: 'news.test',
            strategy: EpgMatchStrategy.exactId,
          ),
        ],
      );

      final schedule = await epgRepository.nowNextForChannel('live:news', now);
      expect(schedule.current?.title, 'Current');
      expect(schedule.next?.title, 'Next');
    },
  );
}
