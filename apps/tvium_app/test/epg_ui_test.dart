import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/app.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_epg/tvium_epg.dart';

void main() {
  testWidgets('shows real Now and Next titles for a matched live channel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final setup = await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('tvium-epg-ui-');
      final repository = SqlitePlaylistRepository.open(
        '${directory.path}/library.sqlite',
      );
      final profile = await repository.ensureDefaultProfile();
      const source = IptvSource(
        id: 'source.test',
        displayName: 'Test source',
        identityDigest: 'digest.test',
        secretReference: 'secret-reference',
      );
      await repository.registerSource(source, profile.id, const [
        PersistedMediaEntry(
          id: 'live:news',
          playlistId: 'source.test',
          sourceReference: 'secret-reference',
          originalName: 'Test News',
          displayName: 'Test News',
          groupName: 'FR | News',
          kind: MediaKind.live,
          epgChannelId: 'guide.news',
        ),
        PersistedMediaEntry(
          id: 'live:other',
          playlistId: 'source.test',
          sourceReference: 'secret-reference',
          originalName: 'Other Channel',
          displayName: 'Other Channel',
          groupName: 'US | News',
          kind: MediaKind.live,
        ),
      ]);
      final now = DateTime.now().toUtc();
      await repository.replaceEpg(
        epgSourceId: 'guide.test',
        channels: const [
          EpgChannel(id: 'guide.news', displayName: 'Test News'),
        ],
        programmes: [
          EpgProgramme(
            channelId: 'guide.news',
            startUtc: now.subtract(const Duration(hours: 1)),
            stopUtc: now.add(const Duration(hours: 1)),
            title: 'Current News',
          ),
          EpgProgramme(
            channelId: 'guide.news',
            startUtc: now.add(const Duration(hours: 1)),
            stopUtc: now.add(const Duration(hours: 2)),
            title: 'Next News',
          ),
        ],
        links: const [
          EpgChannelLink(
            appChannelId: 'live:news',
            epgSourceId: 'guide.test',
            xmltvChannelId: 'guide.news',
            strategy: EpgMatchStrategy.exactId,
          ),
        ],
      );
      return (directory: directory, repository: repository);
    });
    final directory = setup!.directory;
    final repository = setup.repository;
    addTearDown(() async {
      await repository.close();
      await directory.delete(recursive: true);
    });

    await tester.pumpWidget(TviumApp(profileSourceRepository: repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('destination-live')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Current News'), findsOneWidget);
    expect(find.text('Next: Next News'), findsOneWidget);
    expect(find.text('Program guide unavailable'), findsNothing);
    expect(find.byKey(const ValueKey('live-preview-progress')), findsOneWidget);
  });
}
