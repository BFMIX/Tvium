import 'package:test/test.dart';
import 'package:tvium_core/tvium_core.dart';

void main() {
  group('SensitiveDataSanitizer', () {
    test('redacts user info, sensitive path segments, and query values', () {
      const input =
          'Request failed for https://alice:secret@example.test/live/'
          'alice/secret/channel.m3u8?username=alice&password=secret&token=abc';

      final sanitized = SensitiveDataSanitizer.sanitize(input);

      expect(sanitized, contains('example.test'));
      expect(sanitized, isNot(contains('alice')));
      expect(sanitized, isNot(contains('secret')));
      expect(sanitized, isNot(contains('abc')));
      expect(sanitized, contains('username=***'));
      expect(sanitized, contains('password=***'));
      expect(sanitized, contains('token=***'));
    });

    test('redacts credential key-value pairs outside URLs', () {
      const input = 'username=bob password: hunter2 access_token=xyz';

      final sanitized = SensitiveDataSanitizer.sanitize(input);

      expect(sanitized, isNot(contains('bob')));
      expect(sanitized, isNot(contains('hunter2')));
      expect(sanitized, isNot(contains('xyz')));
      expect(sanitized, contains('username=***'));
      expect(sanitized, contains('password: ***'));
      expect(sanitized, contains('access_token=***'));
    });
  });
}
