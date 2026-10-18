import 'package:flutter_test/flutter_test.dart';
import 'package:tvium_app/features/parental/parental_pin_service.dart';

void main() {
  group('ParentalPinService', () {
    final service = ParentalPinService();

    test('creates a versioned digest without retaining the plaintext PIN', () {
      final digest = service.hash('4826');

      expect(digest, startsWith(r'tvium-pin$v1$'));
      expect(digest.split(r'$'), hasLength(6));
      expect(digest.split(r'$'), everyElement(isNot('4826')));
    });

    test('uses a fresh salt for every digest', () {
      final first = service.hash('4826');
      final second = service.hash('4826');

      expect(second, isNot(first));
      expect(service.verify('4826', first), isTrue);
      expect(service.verify('4826', second), isTrue);
    });

    test('rejects an incorrect PIN', () {
      final digest = service.hash('4826');

      expect(service.verify('4827', digest), isFalse);
    });

    test('rejects malformed or unsupported digests', () {
      expect(service.verify('4826', ''), isFalse);
      expect(
        service.verify('4826', r'tvium-pin$v2$sha256$120000$YWJjZA==$YWJjZA=='),
        isFalse,
      );
      expect(
        service.verify(
          '4826',
          r'tvium-pin$v1$sha256$999999999$YWJjZA==$YWJjZA==',
        ),
        isFalse,
      );
    });

    test('accepts only a 4 to 8 digit PIN', () {
      expect(() => service.hash('123'), throwsArgumentError);
      expect(() => service.hash('123456789'), throwsArgumentError);
      expect(() => service.hash('12a4'), throwsArgumentError);
      expect(service.hash('0000'), startsWith(r'tvium-pin$v1$'));
    });
  });
}
