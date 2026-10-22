import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/import/qr_pairing.dart';

void main() {
  test(
    'accepts a synthetic M3U URL without storing it in the pairing link',
    () {
      final submission = parseQrPairingSubmission(
        'type=m3u&url=https%3A%2F%2Fplaylist.example.test%2Flist.m3u',
      );
      expect(submission, isA<QrM3uSubmission>());
      expect((submission as QrM3uSubmission).url.host, 'playlist.example.test');
    },
  );

  test('rejects unsupported and incomplete phone submissions', () {
    expect(parseQrPairingSubmission('type=m3u&url=file%3A%2F%2Flocal'), isNull);
    expect(
      parseQrPairingSubmission(
        'type=xtream&server=https%3A%2F%2Ftv.example.test',
      ),
      isNull,
    );
    expect(
      parseQrPairingSubmission('type=other&url=https%3A%2F%2Ftv.example.test'),
      isNull,
    );
  });

  test('accepts synthetic Xtream credentials only in the phone submission', () {
    final submission = parseQrPairingSubmission(
      'type=xtream&server=https%3A%2F%2Ftv.example.test&username=demo&password=sample',
    );
    expect(submission, isA<QrXtreamSubmission>());
    expect((submission as QrXtreamSubmission).server.host, 'tv.example.test');
  });
}
