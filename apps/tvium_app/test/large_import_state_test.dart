import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/import/m3u_import_persistence.dart';
import 'package:tvium_app/features/import/playlist_import_controller.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

void main() {
  test('large M3U import keeps only a bounded UI preview', () async {
    final body = StringBuffer('#EXTM3U\n');
    for (var index = 0; index < 1500; index++) {
      body.write('#EXTINF:-1 group-title="Fixture",Channel $index\n');
      body.write('https://stream.example.test/$index\n');
    }
    final controller = PlaylistImportController(
      persistence: _MemoryPersistence(),
    );
    addTearDown(controller.dispose);
    await controller.importSource(
      M3uBytesSource(utf8.encode(body.toString())),
      descriptor: const M3uSourceDescriptor.url(
        displayName: 'Fixture',
        location: 'https://playlist.example.test/list.m3u',
      ),
    );
    expect(controller.state.parsedCount, 1500);
    expect(controller.state.entries.length, lessThanOrEqualTo(120));
  });
}

final class _MemoryPersistence implements M3uImportPersistence {
  @override
  Future<String> persist(
    M3uSourceDescriptor descriptor,
    List<M3uEntry> entries,
  ) async => 'fixture';
}
