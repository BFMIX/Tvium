import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/import/xtream_m3u_detector.dart';

void main() {
  test('recognizes a conventional export without exposing credentials', () {
    final candidate = detectXtreamM3u(
      Uri.parse(
        'https://provider.test/sub/get.php?username=alice&password=secret&type=m3u_plus&output=ts',
      ),
    );
    expect(candidate, isNotNull);
    expect(candidate!.serverUri.toString(), 'https://provider.test/sub/');
    expect(candidate.credentials.username, 'alice');
    expect(candidate.toString(), isNot(contains('secret')));
  });

  test('rejects ambiguous or unrelated URLs', () {
    for (final url in <String>[
      'https://provider.test/list.m3u?username=a&password=b',
      'https://provider.test/get.php?username=a&username=b&password=c',
      'https://provider.test/get.php?username=a&password=b#fragment',
      'https://provider.test/get.php?username=a&password=b&output=unknown',
      'https://provider.test/get.php?username=a&password=b&category=movies',
      'https://provider.test/get.php?username=a&password=b&token=extra',
      'https://user:pass@provider.test/get.php?username=a&password=b',
    ]) {
      expect(detectXtreamM3u(Uri.parse(url)), isNull);
    }
  });

  test('preserves an encoded server path and explicit port', () {
    final candidate = detectXtreamM3u(
      Uri.parse(
        'https://provider.test:8443/sub%20path/get.php?username=a&password=b',
      ),
    );
    expect(
      candidate?.serverUri.toString(),
      'https://provider.test:8443/sub%20path/',
    );
  });
}
