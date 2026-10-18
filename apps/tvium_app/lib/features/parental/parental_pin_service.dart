import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hashes parental-control PINs for local persistence.
///
/// The returned value contains only a format version, KDF parameters, a random
/// salt, and the derived digest. The plaintext PIN is never retained.
final class ParentalPinService {
  ParentalPinService({int iterations = defaultIterations, Random? secureRandom})
    : _iterations = iterations,
      _secureRandom = secureRandom ?? Random.secure() {
    if (iterations < minimumIterations || iterations > maximumIterations) {
      throw ArgumentError.value(
        iterations,
        'iterations',
        'must be between $minimumIterations and $maximumIterations',
      );
    }
  }

  static const int defaultIterations = 120000;
  static const int minimumIterations = 100000;
  static const int maximumIterations = 1000000;

  static const _format = 'tvium-pin';
  static const _version = 'v1';
  static const _algorithm = 'sha256';
  static const _saltLength = 16;
  static const _digestLength = 32;

  final int _iterations;
  final Random _secureRandom;

  String hash(String pin) {
    _validatePin(pin);
    final salt = List<int>.generate(
      _saltLength,
      (_) => _secureRandom.nextInt(256),
      growable: false,
    );
    final digest = _derive(pin, salt, _iterations);
    return [
      _format,
      _version,
      _algorithm,
      _iterations.toString(),
      base64Url.encode(salt),
      base64Url.encode(digest),
    ].join(r'$');
  }

  bool verify(String pin, String encodedDigest) {
    if (!_isValidPin(pin)) {
      return false;
    }

    try {
      final parts = encodedDigest.split(r'$');
      if (parts.length != 6 ||
          parts[0] != _format ||
          parts[1] != _version ||
          parts[2] != _algorithm) {
        return false;
      }

      final iterations = int.tryParse(parts[3]);
      if (iterations == null ||
          iterations < minimumIterations ||
          iterations > maximumIterations) {
        return false;
      }

      final salt = base64Url.decode(parts[4]);
      final expected = base64Url.decode(parts[5]);
      if (salt.length != _saltLength || expected.length != _digestLength) {
        return false;
      }

      final actual = _derive(pin, salt, iterations);
      return _constantTimeEquals(actual, expected);
    } on FormatException {
      return false;
    }
  }

  static List<int> _derive(String pin, List<int> salt, int iterations) {
    final pinBytes = utf8.encode(pin);
    var digest = sha256.convert([...salt, ...pinBytes]).bytes;
    for (var round = 1; round < iterations; round += 1) {
      digest = sha256.convert([...digest, ...salt, ...pinBytes]).bytes;
    }
    return digest;
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final length = max(left.length, right.length);
    for (var index = 0; index < length; index += 1) {
      final leftByte = index < left.length ? left[index] : 0;
      final rightByte = index < right.length ? right[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }

  static void _validatePin(String pin) {
    if (!_isValidPin(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must contain 4 to 8 digits');
    }
  }

  static bool _isValidPin(String pin) => RegExp(r'^\d{4,8}$').hasMatch(pin);
}
