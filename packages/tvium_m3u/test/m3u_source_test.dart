import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

void main() {
  group('M3uBytesSource', () {
    test('streams UTF-8 bytes without requiring a local file path', () async {
      final source = M3uBytesSource(
        Uint8List.fromList(<int>[
          35,
          69,
          88,
          84,
          77,
          51,
          85,
          10,
          35,
          69,
          88,
          84,
          73,
          78,
          70,
          58,
          45,
          49,
          44,
          68,
          101,
          109,
          111,
        ]),
      );

      expect(await source.readLines().toList(), <String>[
        '#EXTM3U',
        '#EXTINF:-1,Demo',
      ]);
    });
  });

  group('M3uFileSource', () {
    test('streams LF and CRLF files as individual lines', () async {
      final directory = await Directory.systemTemp.createTemp('tvium-m3u-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/fixture.m3u');
      await file.writeAsString(
        '#EXTM3U\r\n#EXTINF:-1,Demo\nhttps://example.test/live',
      );

      final lines = await M3uFileSource(file.path).readLines().toList();

      expect(lines, <String>[
        '#EXTM3U',
        '#EXTINF:-1,Demo',
        'https://example.test/live',
      ]);
    });
  });

  group('M3uUrlSource', () {
    test('streams a successful HTTP response', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'playlist.example.test');
        return http.Response(
          '#EXTM3U\n#EXTINF:-1,Demo\nhttps://example.test/live',
          200,
        );
      });

      final lines = await M3uUrlSource(
        Uri.parse('https://playlist.example.test/list.m3u'),
        client: client,
      ).readLines().toList();

      expect(lines, hasLength(3));
      expect(lines.last, 'https://example.test/live');
    });

    test('throws a sanitized failure for a rejected request', () async {
      final client = MockClient(
        (request) async => http.Response('Denied', 401),
      );
      final source = M3uUrlSource(
        Uri.parse(
          'https://alice:secret@playlist.example.test/get.php?username=alice&password=secret',
        ),
        client: client,
      );

      expect(
        source.readLines().toList,
        throwsA(
          isA<M3uSourceException>()
              .having((error) => error.message, 'message', contains('401'))
              .having(
                (error) => error.message,
                'message',
                isNot(contains('alice')),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('secret')),
              ),
        ),
      );
    });

    test('stops when a playlist body stalls after parsed rows', () async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final client = _StreamingClient(body.stream);
      addTearDown(client.close);
      final source = M3uUrlSource(
        Uri.parse('https://playlist.example.test/list.m3u'),
        client: client,
        timeout: const Duration(milliseconds: 50),
      );
      final lines = source.readLines().toList();
      body.add(
        utf8.encode(
          '#EXTM3U\n#EXTINF:-1,Demo\nhttps://stream.example.test/live\n',
        ),
      );

      await expectLater(
        lines,
        throwsA(
          isA<M3uSourceException>().having(
            (error) => error.message,
            'message',
            'Playlist request timed out',
          ),
        ),
      );
      expect(cancelled, isTrue);
    });

    test('stops a never-ending trickle before the overall deadline', () async {
      final body = StreamController<List<int>>();
      final timer = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => body.add(utf8.encode('#EXTINF:-1,Demo\n')),
      );
      addTearDown(timer.cancel);
      final client = _StreamingClient(body.stream);
      addTearDown(client.close);
      final source = M3uUrlSource(
        Uri.parse('https://playlist.example.test/list.m3u'),
        client: client,
        timeout: const Duration(milliseconds: 100),
        maxDuration: const Duration(milliseconds: 200),
      );

      await expectLater(
        source.readLines().toList(),
        throwsA(isA<M3uSourceException>()),
      );
    });
  });
}

final class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.body);

  final Stream<List<int>> body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(body, 200);
}
