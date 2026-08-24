import 'package:test/test.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

void main() {
  test('generates deterministic fictional entries with mixed media kinds', () {
    const generator = SyntheticM3uGenerator();

    final first = generator.generateLines(20).toList();
    final second = generator.generateLines(20).toList();

    expect(first, second);
    expect(first.where((line) => line.startsWith('#EXTINF:')), hasLength(20));
    expect(first.where((line) => line.startsWith('https://')), hasLength(20));
    expect(first.every((line) => !line.contains('localhost')), isTrue);
    expect(first.join('\n'), contains('stream.example.test'));
    expect(first.join('\n'), contains('Synthetic Movie'));
    expect(first.join('\n'), contains('Synthetic Show S'));
    expect(first.join('\n'), contains('Synthetic Channel'));
  });
}
