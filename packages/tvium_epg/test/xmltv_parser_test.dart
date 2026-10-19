import 'dart:convert';

import 'package:test/test.dart';
import 'package:tvium_epg/tvium_epg.dart';

Future<EpgImportResult> parse(String xml, {int chunkSize = 7}) {
  final bytes = utf8.encode(xml);
  return XmltvParser().parse(
    Stream.fromIterable([
      for (var i = 0; i < bytes.length; i += chunkSize)
        bytes.sublist(i, (i + chunkSize).clamp(0, bytes.length)),
    ]),
  );
}

String programme({
  String start = '20261016120000 +0200',
  String stop = '20261016130000 +0200',
  String channel = 'news.test',
  String body = '<title>News</title>',
}) =>
    '<programme channel="$channel" start="$start" stop="$stop">'
    '$body</programme>';

void main() {
  test('programme model normalizes caller-provided timestamps to UTC', () {
    final start = DateTime(2026, 10, 16, 12);
    final stop = DateTime(2026, 10, 16, 13);
    final entry = EpgProgramme(
      channelId: 'news.test',
      startUtc: start,
      stopUtc: stop,
      title: 'News',
    );
    expect(entry.startUtc.isUtc, isTrue);
    expect(entry.stopUtc.isUtc, isTrue);
    expect(entry.startUtc.isAtSameMomentAs(start), isTrue);
    expect(entry.stopUtc.isAtSameMomentAs(stop), isTrue);
  });

  group('XmltvParser', () {
    test(
      'decodes chunked UTF-8 without losing multi-byte characters',
      () async {
        final result = await parse(
          '<tv><channel id="news.test"><display-name>Été 📺</display-name>'
          '<icon src="https://images.test/icon.png"/></channel>'
          '${programme(body: '<title>Édition du soir 📺</title>')}</tv>',
          chunkSize: 1,
        );
        expect(result.channels.single.id, 'news.test');
        expect(result.channels.single.displayName, 'Été 📺');
        expect(
          result.channels.single.iconUri,
          Uri.parse('https://images.test/icon.png'),
        );
        expect(result.programmes.single.title, 'Édition du soir 📺');
        expect(result.warnings, isEmpty);
      },
    );

    test('converts positive XMLTV offset to UTC', () async {
      final result = await parse('<tv>${programme()}</tv>');
      expect(result.programmes.single.startUtc, DateTime.utc(2026, 10, 16, 10));
      expect(result.programmes.single.stopUtc, DateTime.utc(2026, 10, 16, 11));
      expect(result.programmes.single.startUtc.isUtc, isTrue);
    });

    test('converts negative half-hour offset across day boundary', () async {
      final result = await parse(
        '<tv>${programme(start: '20261016233000 -0330', stop: '20261017003000 -0330')}</tv>',
      );
      expect(result.programmes.single.startUtc, DateTime.utc(2026, 10, 17, 3));
      expect(result.programmes.single.stopUtc, DateTime.utc(2026, 10, 17, 4));
    });

    test('uses UTC when XMLTV timestamp has no offset', () async {
      final result = await parse(
        '<tv>${programme(start: '20261016120000', stop: '20261016130000')}</tv>',
      );
      expect(result.programmes.single.startUtc, DateTime.utc(2026, 10, 16, 12));
    });

    test('keeps optional subtitle description and repeated categories', () async {
      final result = await parse(
        '<tv>${programme(body: '<title> News </title><sub-title> Evening </sub-title><desc><![CDATA[Arts & culture]]></desc><category>News</category><category>Local</category>')}</tv>',
      );
      final entry = result.programmes.single;
      expect(entry.title, 'News');
      expect(entry.subtitle, 'Evening');
      expect(entry.description, 'Arts & culture');
      expect(entry.categories, ['News', 'Local']);
    });

    test('leaves absent optional fields null and categories empty', () async {
      final result = await parse(
        '<tv><channel id="news.test"><display-name>News</display-name></channel>${programme()}</tv>',
      );
      expect(result.channels.single.iconUri, isNull);
      expect(result.programmes.single.subtitle, isNull);
      expect(result.programmes.single.description, isNull);
      expect(result.programmes.single.categories, isEmpty);
    });

    for (final invalid in <String>[
      programme(start: 'nonsense'),
      programme(start: '20260230120000 +0000'),
      programme(start: '20261016250000 +0000'),
      programme(start: '20261016120000 +2460'),
      programme(stop: '20261016110000 +0200'),
      programme(stop: '20261016120000 +0200'),
      programme(channel: ''),
      programme(body: '<desc>No title</desc>'),
    ]) {
      test(
        'skips semantic-invalid programme without losing valid neighbours: $invalid',
        () async {
          final result = await parse(
            '<tv>${programme()}$invalid${programme(body: '<title>Later</title>')}</tv>',
          );
          expect(result.programmes.map((entry) => entry.title), [
            'News',
            'Later',
          ]);
          expect(result.warnings, hasLength(1));
        },
      );
    }

    test('sanitizes warnings without reflecting untrusted attributes', () async {
      final result = await parse(
        '<tv>${programme(channel: 'https://provider.test/private?token=secret', start: 'bad')}</tv>',
      );
      expect(result.warnings.single, isNot(contains('provider.test')));
      expect(result.warnings.single, isNot(contains('secret')));
    });

    for (final xml in [
      '<!DOCTYPE tv><tv/>',
      '<!DOCTYPE tv SYSTEM "https://external.test/entity"><tv/>',
      '<!DOCTYPE tv [<!ENTITY leak SYSTEM "file:///private.test">]><tv/>',
      '<tv><channel id="x.test"><display-name>&custom;</display-name></channel></tv>',
      '<tv><channel id="&custom;"/></tv>',
    ]) {
      test('rejects doctype or custom entity: $xml', () async {
        await expectLater(parse(xml, chunkSize: 1), throwsFormatException);
      });
    }

    test('decodes only standard XML character references', () async {
      final result = await parse(
        '<tv>${programme(body: '<title>Arts &amp; &#x1F4FA; &#233;</title>')}</tv>',
        chunkSize: 1,
      );
      expect(result.programmes.single.title, 'Arts & 📺 é');
    });

    for (final xml in [
      '<tv><channel></tv>',
      '<tv>',
      '<tv/><tv/>',
      '<html/>',
      '',
    ]) {
      test('rejects invalid XMLTV document: $xml', () async {
        await expectLater(parse(xml), throwsFormatException);
      });
    }

    test('exposes immutable import collections and programme categories', () async {
      final result = await parse(
        '<tv>${programme(body: '<title>News</title><category>Local</category>')}</tv>',
      );
      expect(() => result.channels.clear(), throwsUnsupportedError);
      expect(() => result.programmes.clear(), throwsUnsupportedError);
      expect(() => result.warnings.add('changed'), throwsUnsupportedError);
      expect(
        () => result.programmes.single.categories.clear(),
        throwsUnsupportedError,
      );
    });
  });
}
